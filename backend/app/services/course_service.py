"""ProfessorOS – Course service (CRUD, enrollment, CLO management)."""

import csv
import io
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course import CLO, Course, Enrollment
from app.models.user import User
from app.schemas.course import CourseCreate, CourseUpdate
from app.services.student_access import can_student_join_course


class CourseService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_courses(self, user: User) -> List[Course]:
        options = (
            selectinload(Course.professor),
            selectinload(Course.enrollments).selectinload(Enrollment.user),
            selectinload(Course.assignments),
        )
        if user.role == "admin":
            result = await self.db.execute(
                select(Course).options(*options).order_by(Course.created_at.desc())
            )
            return list(result.scalars().unique().all())
        if user.role == "professor":
            result = await self.db.execute(
                select(Course).options(*options)
                .where(Course.professor_id == user.id)
                .order_by(Course.created_at.desc())
            )
            return list(result.scalars().unique().all())
        result = await self.db.execute(
            select(Course).options(*options)
            .join(Enrollment)
            .where(Enrollment.user_id == user.id)
            .order_by(Course.created_at.desc())
        )
        return list(result.scalars().unique().all())

    async def create_course(self, data: CourseCreate, professor_id: int) -> Course:
        # Validate that professor_id belongs to an approved professor
        professor = await self.db.get(User, professor_id)
        if not professor:
            raise ValueError("Professor not found.")
        if professor.role != "professor":
            raise ValueError("The selected user is not a professor.")
        if not professor.is_approved:
            raise ValueError("The selected professor's account is not yet approved.")

        total = data.quiz_weight + data.assignment_weight + data.midterm_weight + data.final_weight
        if total != 100:
            raise ValueError(f"HEC weights must sum to 100 (currently {total}).")
        course = Course(
            title=data.title, code=data.code.upper(), semester=data.semester,
            description=data.description, at_risk_threshold=data.at_risk_threshold,
            quiz_weight=data.quiz_weight, assignment_weight=data.assignment_weight,
            midterm_weight=data.midterm_weight, final_weight=data.final_weight,
            professor_id=professor_id,
        )
        self.db.add(course)
        await self.db.flush()
        return course

    async def get_course(self, course_id: int) -> Course:
        result = await self.db.execute(
            select(Course)
            .options(
                selectinload(Course.professor),
                selectinload(Course.enrollments).selectinload(Enrollment.user),
                selectinload(Course.assignments),
            )
            .where(Course.id == course_id)
        )
        course = result.scalar_one_or_none()
        if not course:
            raise ValueError("Course not found.")
        return course

    async def get_course_with_access_check(self, course_id: int, user: User) -> Course:
        """Get course only if user has permission (professor owner, admin, or enrolled student)."""
        course = await self.get_course(course_id)
        
        # Admin can view any course
        if user.role == "admin":
            return course
        
        # Professor can view only their own courses
        if user.role == "professor":
            if course.professor_id != user.id:
                raise PermissionError("No permission to view this course.")
            return course
        
        # Students can view only if enrolled
        enrollment_result = await self.db.execute(
            select(Enrollment).where(
                Enrollment.course_id == course_id,
                Enrollment.user_id == user.id
            )
        )
        if not enrollment_result.scalar_one_or_none():
            raise PermissionError("No permission to view this course.")
        
        return course

    async def verify_course_management_access(self, course_id: int, user: User) -> Course:
        """Verify user can manage course (edit enrollments, CLOs, etc.)."""
        course = await self.get_course(course_id)
        
        # Only professor owner or admin can manage
        if user.role == "admin":
            return course
        
        if user.role != "professor" or course.professor_id != user.id:
            raise PermissionError("No permission to manage this course.")
        
        return course

    async def update_course(self, course_id: int, data: CourseUpdate, user: User) -> Course:
        course = await self.get_course(course_id)
        if course.professor_id != user.id and user.role != "admin":
            raise PermissionError("No permission to edit this course.")
        update_data = data.model_dump(exclude_unset=True)
        weight_keys = {"quiz_weight", "assignment_weight", "midterm_weight", "final_weight"}
        if weight_keys & set(update_data.keys()):
            q = update_data.get("quiz_weight", course.quiz_weight)
            a = update_data.get("assignment_weight", course.assignment_weight)
            m = update_data.get("midterm_weight", course.midterm_weight)
            f = update_data.get("final_weight", course.final_weight)
            if q + a + m + f != 100:
                raise ValueError(f"HEC weights must sum to 100 (currently {q+a+m+f}).")
        for key, value in update_data.items():
            if key == "code" and value:
                value = value.upper()
            setattr(course, key, value)
        await self.db.flush()
        return course

    async def archive_course(self, course_id: int, user: User) -> Course:
        course = await self.get_course(course_id)
        if course.professor_id != user.id and user.role != "admin":
            raise PermissionError("No permission to archive this course.")
        course.is_archived = True
        await self.db.flush()
        return course

    async def delete_course(self, course_id: int, user: User) -> None:
        course = await self.get_course(course_id)
        if course.professor_id != user.id and user.role != "admin":
            raise PermissionError("No permission to delete this course.")
        await self.db.delete(course)
        await self.db.flush()

    async def enroll_user(self, course_id: int, user_id: int, role: str = "student") -> Enrollment:
        if role not in ("student", "ta"):
            raise ValueError(f"Invalid enrollment role: {role}. Must be 'student' or 'ta'.")
        result = await self.db.execute(
            select(Enrollment).where(Enrollment.course_id == course_id, Enrollment.user_id == user_id)
        )
        if result.scalar_one_or_none():
            raise ValueError("User already enrolled.")
        enrollment = Enrollment(course_id=course_id, user_id=user_id, role=role)
        self.db.add(enrollment)
        await self.db.flush()
        return enrollment

    async def remove_enrollment(self, course_id: int, user_id: int) -> None:
        result = await self.db.execute(
            select(Enrollment).where(Enrollment.course_id == course_id, Enrollment.user_id == user_id)
        )
        enrollment = result.scalar_one_or_none()
        if not enrollment:
            raise ValueError("Enrollment not found.")
        await self.db.delete(enrollment)
        await self.db.flush()

    async def import_enrollments_csv(self, course_id: int, file_content: bytes) -> dict:
        created = 0
        errors = []
        text = file_content.decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(text))
        for row_num, row in enumerate(reader, start=2):
            email = (row.get("email") or "").strip().lower()
            role = (row.get("role") or "student").strip().lower()
            if not email:
                errors.append({"row": row_num, "email": "", "reason": "Email required."})
                continue
            result = await self.db.execute(select(User).where(User.email == email))
            user = result.scalar_one_or_none()
            if not user:
                errors.append({"row": row_num, "email": email, "reason": "User not found."})
                continue
            result = await self.db.execute(
                select(Enrollment).where(Enrollment.course_id == course_id, Enrollment.user_id == user.id)
            )
            if result.scalar_one_or_none():
                errors.append({"row": row_num, "email": email, "reason": "Already enrolled."})
                continue
            self.db.add(Enrollment(course_id=course_id, user_id=user.id, role=role))
            created += 1
        await self.db.flush()
        await self.db.commit()
        return {"created": created, "errors": errors}

    async def list_enrollments(self, course_id: int) -> List[Enrollment]:
        result = await self.db.execute(
            select(Enrollment)
            .options(selectinload(Enrollment.user))
            .where(Enrollment.course_id == course_id)
        )
        return list(result.scalars().all())

    async def list_clos(self, course_id: int) -> List[CLO]:
        result = await self.db.execute(select(CLO).where(CLO.course_id == course_id).order_by(CLO.code))
        return list(result.scalars().all())

    async def create_clo(self, course_id: int, code: str, description: str) -> CLO:
        clo = CLO(course_id=course_id, code=code, description=description)
        self.db.add(clo)
        await self.db.flush()
        return clo

    async def delete_clo(self, course_id: int, clo_id: int) -> None:
        result = await self.db.execute(
            select(CLO).where(CLO.course_id == course_id, CLO.id == clo_id)
        )
        clo = result.scalar_one_or_none()
        if not clo:
            raise ValueError("CLO not found.")
        await self.db.delete(clo)
        await self.db.flush()


    async def join_course(self, user_id: int, join_code: str) -> Enrollment:
        user = await self.db.get(User, user_id)
        if not user or not can_student_join_course(user):
            raise PermissionError("Only approved active student accounts can join courses.")
        code_clean = join_code.strip().upper()
        result = await self.db.execute(
            select(Course).where(Course.join_code == code_clean, Course.is_archived == False)
        )
        course = result.scalar_one_or_none()
        if not course:
            raise ValueError("Invalid join code or course does not exist.")

        enroll_res = await self.db.execute(
            select(Enrollment).where(Enrollment.course_id == course.id, Enrollment.user_id == user_id)
        )
        if enroll_res.scalar_one_or_none():
            raise ValueError("You are already enrolled in this course.")

        enrollment = Enrollment(course_id=course.id, user_id=user_id, role="student")
        self.db.add(enrollment)
        await self.db.flush()
        return enrollment
