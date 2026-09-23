"""ProfessorOS – Submission service (submit, grade, list)."""

import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.submission import Submission, SubmissionStatus
from app.models.assignment import Assignment
from app.schemas.submission import SubmissionCreate, SubmissionGrade
from app.config.settings import get_settings

# Directory for uploaded submission files
SUBMISSIONS_DIR = Path(get_settings().STORAGE_ROOT) / "submissions"


class SubmissionService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def submit(
        self,
        assignment_id: int,
        student_id: int,
        data: SubmissionCreate,
    ) -> Submission:
        """Create or update a student's submission (one per student per assignment)."""
        # Check assignment exists and is published
        assignment = await self.db.get(Assignment, assignment_id)
        if not assignment:
            raise ValueError("Assignment not found.")
        if assignment.status != "published":
            raise ValueError("Assignment is not yet published.")

        # Check if already submitted (update instead of create)
        existing = await self._get_submission(assignment_id, student_id)
        if existing:
            # Allow resubmission – update content, reset to pending
            existing.content = data.content
            existing.submission_type = data.submission_type
            existing.status = SubmissionStatus.PENDING.value
            existing.score = None
            existing.feedback = None
            existing.graded_by_id = None
            existing.graded_at = None
            existing.submitted_at = datetime.now(timezone.utc)
            await self.db.flush()
            return existing

        submission = Submission(
            assignment_id=assignment_id,
            student_id=student_id,
            submission_type=data.submission_type,
            content=data.content,
            status=SubmissionStatus.PENDING.value,
        )
        self.db.add(submission)
        await self.db.flush()
        return await self._reload(submission.id)

    async def save_file(
        self,
        assignment_id: int,
        student_id: int,
        file_bytes: bytes,
        filename: str,
    ) -> Submission:
        """Save a file submission and create/update the Submission record."""
        assignment = await self.db.get(Assignment, assignment_id)
        if not assignment:
            raise ValueError("Assignment not found.")
        if assignment.status != "published":
            raise ValueError("Assignment is not yet published.")

        # Persist file to disk
        SUBMISSIONS_DIR.mkdir(parents=True, exist_ok=True)
        original_name = Path(filename or "submission.bin").name
        safe_name_part = re.sub(r"[^A-Za-z0-9_.-]", "_", original_name) or "submission.bin"
        safe_name = f"{assignment_id}_{student_id}_{safe_name_part}"
        file_path = SUBMISSIONS_DIR / safe_name
        file_path.write_bytes(file_bytes)

        existing = await self._get_submission(assignment_id, student_id)
        if existing:
            existing.submission_type = "file"
            existing.file_path = str(file_path)
            existing.file_name = filename
            existing.content = None
            existing.status = SubmissionStatus.PENDING.value
            existing.score = None
            existing.feedback = None
            existing.graded_by_id = None
            existing.graded_at = None
            existing.submitted_at = datetime.now(timezone.utc)
            await self.db.flush()
            return existing

        submission = Submission(
            assignment_id=assignment_id,
            student_id=student_id,
            submission_type="file",
            file_path=str(file_path),
            file_name=filename,
            status=SubmissionStatus.PENDING.value,
        )
        self.db.add(submission)
        await self.db.flush()
        return await self._reload(submission.id)

    async def list_submissions(self, assignment_id: int) -> List[Submission]:
        """List all submissions for an assignment (prof/TA view)."""
        result = await self.db.execute(
            select(Submission)
            .options(
                selectinload(Submission.student),
                selectinload(Submission.graded_by),
            )
            .where(Submission.assignment_id == assignment_id)
            .order_by(Submission.submitted_at.desc())
        )
        return list(result.scalars().all())

    async def get_submission(self, submission_id: int) -> Submission:
        return await self._reload(submission_id)

    async def get_my_submission(self, assignment_id: int, student_id: int) -> Optional[Submission]:
        """Get a student's own submission."""
        return await self._get_submission(assignment_id, student_id)

    async def grade_submission(
        self,
        submission_id: int,
        data: SubmissionGrade,
        grader_id: int,
    ) -> Submission:
        """Save grade and feedback. Triggers analytics refresh."""
        result = await self.db.execute(
            select(Submission)
            .options(selectinload(Submission.student), selectinload(Submission.graded_by))
            .where(Submission.id == submission_id)
        )
        submission = result.scalar_one_or_none()
        if not submission:
            raise ValueError("Submission not found.")

        submission.score = data.score
        submission.feedback = data.feedback
        submission.status = SubmissionStatus.GRADED.value
        submission.graded_by_id = grader_id
        submission.graded_at = datetime.now(timezone.utc)
        await self.db.flush()

        # Trigger live analytics recomputation
        await self._recompute_analytics(submission.assignment_id)

        return submission

    # ── Private helpers ───────────────────────────────

    async def _get_submission(self, assignment_id: int, student_id: int) -> Optional[Submission]:
        result = await self.db.execute(
            select(Submission)
            .options(selectinload(Submission.student), selectinload(Submission.graded_by))
            .where(
                Submission.assignment_id == assignment_id,
                Submission.student_id == student_id,
            )
        )
        return result.scalar_one_or_none()

    async def _reload(self, submission_id: int) -> Submission:
        result = await self.db.execute(
            select(Submission)
            .options(selectinload(Submission.student), selectinload(Submission.graded_by))
            .where(Submission.id == submission_id)
        )
        return result.scalar_one()

    async def _recompute_analytics(self, assignment_id: int) -> None:
        """Pull real scores from DB and refresh the course analytics snapshot."""
        try:
            from sqlalchemy import text
            # Get course_id for this assignment
            result = await self.db.execute(
                text("SELECT course_id FROM assignments WHERE id = :aid"),
                {"aid": assignment_id},
            )
            row = result.fetchone()
            if not row:
                return
            course_id = row[0]

            # Pull all graded submission scores for the course
            score_result = await self.db.execute(
                text(
                    "SELECT s.score, s.student_id FROM submissions s "
                    "JOIN assignments a ON a.id = s.assignment_id "
                    "WHERE a.course_id = :cid AND s.status = 'graded' AND s.score IS NOT NULL"
                ),
                {"cid": course_id},
            )
            rows = score_result.fetchall()
            if not rows:
                return

            scores = [float(r[0]) for r in rows]
            student_scores = {int(r[1]): float(r[0]) for r in rows}

            from app.services.analytics_service import AnalyticsService
            from app.services.cache_service import cache_delete
            analytics_svc = AnalyticsService(self.db)
            course = None
            try:
                from app.services.course_service import CourseService
                course = await CourseService(self.db).get_course(course_id)
            except Exception:
                pass

            threshold = course.at_risk_threshold if course else 50.0
            await analytics_svc.compute_analytics(course_id, scores)
            await analytics_svc.detect_at_risk_students(course_id, threshold, student_scores)
            # Invalidate cache
            await cache_delete(f"analytics:{course_id}")
        except Exception as e:
            print(f"[ANALYTICS] Recompute failed: {e}")
