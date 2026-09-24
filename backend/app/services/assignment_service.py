"""ProfessorOS – Assignment service (CRUD, HEC publish validation)."""

from typing import List, Optional

from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.assignment import Assignment, AssignmentStatus, assignment_clo_table, assignment_ta_table
from app.models.course import CLO, Enrollment
from app.models.user import User
from app.services.assignment_access import can_access_assignment
from app.models.rubric import Rubric, RubricCriterion, RubricLevel, LevelName
from app.schemas.assignment import AssignmentCreate, AssignmentUpdate
from app.schemas.rubric import RubricCreate


class AssignmentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_assignments(self, course_id: int, status_filter: Optional[str] = None) -> List[Assignment]:
        query = select(Assignment).where(Assignment.course_id == course_id)
        if status_filter and status_filter != "all":
            query = query.where(Assignment.status == status_filter)
        query = query.order_by(Assignment.created_at.desc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def create_assignment(self, course_id: int, data: AssignmentCreate) -> Assignment:
        assignment = Assignment(
            course_id=course_id, title=data.title, description=data.description,
            type=data.type, max_marks=data.max_marks, deadline=data.deadline,
            allow_late=data.allow_late, late_penalty_per_day=data.late_penalty_per_day,
            max_penalty_cap=data.max_penalty_cap, status=AssignmentStatus.DRAFT.value,
        )
        self.db.add(assignment)
        await self.db.flush()

        # Link CLOs
        if data.clo_ids:
            for clo_id in data.clo_ids:
                await self.db.execute(
                    assignment_clo_table.insert().values(assignment_id=assignment.id, clo_id=clo_id)
                )
            await self.db.flush()
        return await self.get_assignment(assignment.id)

    async def get_assignment(self, assignment_id: int) -> Assignment:
        result = await self.db.execute(
            select(Assignment)
            .options(
                selectinload(Assignment.clos),
                selectinload(Assignment.rubric).selectinload(Rubric.criteria),
                selectinload(Assignment.course),
            )
            .where(Assignment.id == assignment_id)
        )
        assignment = result.scalar_one_or_none()
        if not assignment:
            raise ValueError("Assignment not found.")
        return assignment

    async def delegated_ta_ids(self, assignment_id: int) -> set[int]:
        result = await self.db.execute(
            select(assignment_ta_table.c.user_id).where(
                assignment_ta_table.c.assignment_id == assignment_id
            )
        )
        return {row[0] for row in result.all()}

    async def delegated_ta_ids_for_user(self, course_id: int, user_id: int) -> set[int]:
        result = await self.db.execute(
            select(assignment_ta_table.c.assignment_id)
            .join(Assignment, Assignment.id == assignment_ta_table.c.assignment_id)
            .where(
                Assignment.course_id == course_id,
                assignment_ta_table.c.user_id == user_id,
            )
        )
        return {row[0] for row in result.all()}

    async def enrolled_student_ids(self, course_id: int) -> set[int]:
        result = await self.db.execute(
            select(Enrollment.user_id).where(
                Enrollment.course_id == course_id,
            )
        )
        return {row[0] for row in result.all()}

    async def verify_assignment_access(self, assignment_id: int, user: User) -> Assignment:
        assignment = await self.get_assignment(assignment_id)
        role = getattr(user.role, "value", user.role)
        enrolled_students = None
        if role == "student":
            enrolled_students = await self.enrolled_student_ids(assignment.course_id)
            if user.id not in enrolled_students:
                raise PermissionError("You are not enrolled in this course.")
            if (assignment.status or "").lower() == "draft":
                raise PermissionError("Assignment is not yet published.")
            return assignment

        if not can_access_assignment(
            user_role=user.role,
            user_id=user.id,
            assignment=assignment,
            delegated_ta_ids=await self.delegated_ta_ids(assignment_id),
            enrolled_student_ids=enrolled_students,
        ):
            raise PermissionError("You are not assigned to this assignment.")
        return assignment

    async def list_delegated_tas(self, assignment_id: int) -> list[dict]:
        result = await self.db.execute(
            select(User.id, User.full_name, User.email, assignment_ta_table.c.batch_size)
            .join(assignment_ta_table, assignment_ta_table.c.user_id == User.id)
            .where(assignment_ta_table.c.assignment_id == assignment_id)
            .order_by(User.full_name)
        )
        return [
            {
                "user_id": row.id,
                "user_name": row.full_name,
                "user_email": row.email,
                "batch_size": row.batch_size,
            }
            for row in result
        ]

    async def delegate_ta(self, assignment_id: int, ta_user_id: int) -> dict:
        assignment = await self.get_assignment(assignment_id)
        enrollment_result = await self.db.execute(
            select(Enrollment).where(
                Enrollment.course_id == assignment.course_id,
                Enrollment.user_id == ta_user_id,
                Enrollment.role == "ta",
            )
        )
        if not enrollment_result.scalar_one_or_none():
            raise ValueError("The user must be enrolled as a TA in this course first.")

        existing = await self.db.execute(
            select(assignment_ta_table.c.user_id).where(
                assignment_ta_table.c.assignment_id == assignment_id,
                assignment_ta_table.c.user_id == ta_user_id,
            )
        )
        if existing.first():
            raise ValueError("This TA is already assigned to the assignment.")

        await self.db.execute(
            assignment_ta_table.insert().values(
                assignment_id=assignment_id,
                user_id=ta_user_id,
                batch_size=None,
            )
        )
        await self.db.flush()
        return next(row for row in await self.list_delegated_tas(assignment_id) if row["user_id"] == ta_user_id)

    async def remove_ta(self, assignment_id: int, ta_user_id: int) -> None:
        result = await self.db.execute(
            delete(assignment_ta_table).where(
                assignment_ta_table.c.assignment_id == assignment_id,
                assignment_ta_table.c.user_id == ta_user_id,
            )
        )
        if result.rowcount == 0:
            raise ValueError("TA assignment not found.")
        await self.db.flush()

    async def update_assignment(self, assignment_id: int, data: AssignmentUpdate) -> Assignment:
        assignment = await self.get_assignment(assignment_id)
        update_data = data.model_dump(exclude_unset=True)
        clo_ids = update_data.pop("clo_ids", None)
        for key, value in update_data.items():
            setattr(assignment, key, value)
        if clo_ids is not None:
            await self.db.execute(
                assignment_clo_table.delete().where(assignment_clo_table.c.assignment_id == assignment_id)
            )
            for clo_id in clo_ids:
                await self.db.execute(
                    assignment_clo_table.insert().values(assignment_id=assignment_id, clo_id=clo_id)
                )
        await self.db.flush()
        return await self.get_assignment(assignment_id)

    async def publish_assignment(self, assignment_id: int) -> Assignment:
        """Publish with full HEC validation."""
        assignment = await self.get_assignment(assignment_id)
        errors = []

        # 1. Must have a rubric
        if not assignment.rubric:
            errors.append("A rubric is required before publishing.")
        else:
            criteria = assignment.rubric.criteria
            # 2. Min 3, max 10 criteria
            if len(criteria) < 3:
                errors.append(f"Rubric must have at least 3 criteria (currently {len(criteria)}).")
            if len(criteria) > 10:
                errors.append(f"Rubric must have at most 10 criteria (currently {len(criteria)}).")
            # 3. Weights must sum to 100
            total_weight = sum(c.weight for c in criteria)
            if abs(total_weight - 100.0) > 0.01:
                errors.append(f"Rubric weights must sum to 100 (currently {total_weight:.1f}).")
            # 4. Each criterion must have 4 levels
            for c in criteria:
                if len(c.levels) != 4:
                    errors.append(f"Criterion '{c.name}' must have exactly 4 levels (has {len(c.levels)}).")

        # 5. Must be linked to at least one CLO
        if not assignment.clos:
            errors.append("Assignment must be linked to at least one CLO.")

        if errors:
            raise ValueError(" | ".join(errors))

        assignment.status = AssignmentStatus.PUBLISHED.value
        await self.db.flush()
        return assignment

    # ── Rubric CRUD ───────────────────────────────────

    async def get_rubric(self, assignment_id: int) -> Optional[Rubric]:
        result = await self.db.execute(
            select(Rubric).where(Rubric.assignment_id == assignment_id)
        )
        return result.scalar_one_or_none()

    async def create_or_update_rubric(self, assignment_id: int, data: RubricCreate) -> Rubric:
        # Delete existing rubric if any
        existing = await self.get_rubric(assignment_id)
        if existing:
            await self.db.delete(existing)
            await self.db.flush()

        rubric = Rubric(assignment_id=assignment_id)
        self.db.add(rubric)
        await self.db.flush()

        for idx, crit_data in enumerate(data.criteria):
            criterion = RubricCriterion(
                rubric_id=rubric.id, name=crit_data.name,
                weight=crit_data.weight, order=idx,
            )
            self.db.add(criterion)
            await self.db.flush()

            # Create all 4 levels
            if crit_data.levels:
                for level_data in crit_data.levels:
                    level = RubricLevel(
                        criterion_id=criterion.id,
                        level=level_data.level,
                        description=level_data.description,
                    )
                    self.db.add(level)
            else:
                # Auto-create empty 4 levels
                for level_name in LevelName:
                    level = RubricLevel(
                        criterion_id=criterion.id, level=level_name.value, description=""
                    )
                    self.db.add(level)
            await self.db.flush()

        # Reload
        return await self.get_rubric(assignment_id)
