"""ProfessorOS – Exam session endpoints (anti-cheat tracking)."""

from datetime import datetime, timezone
from typing import Annotated, List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.models.exam_attempt import ExamAttempt
from app.models.assignment import Assignment
from app.services.course_service import CourseService

router = APIRouter(tags=["Exams"])


@router.post("/courses/{course_id}/assignments/{assignment_id}/exam/start")
async def start_exam(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Student starts (or resumes) an exam attempt. Returns time limit, attempt ID
    and the authoritative anti-cheat state so the client can sync its local counters."""

    # Enforce full account status before allowing exam access. A suspended,
    # unverified or unapproved student must not be able to sit an exam even
    # if they hold a valid attempt count.
    if not (user.is_active and user.is_verified and user.is_approved):
        raise HTTPException(
            status_code=403,
            detail="Account must be verified, approved and active to start this exam.",
        )

    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).get_course_with_access_check(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    if assignment.status != "published":
        raise HTTPException(status_code=400, detail="Assignment is not published.")

    # Load every attempt for this student/assignment with row-level lock
    # to prevent concurrent race condition exploits.
    result = await db.execute(
        select(ExamAttempt)
        .where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == user.id,
        )
        .with_for_update()
    )
    existing_attempts = result.scalars().all()

    # Resume an existing active (unsubmitted) attempt instead of minting a
    # duplicate. Without this a student could open several concurrent sessions
    # and bypass max_attempts, and a network drop would silently consume an
    # extra attempt.
    active_attempt = next(
        (a for a in existing_attempts if a.submitted_at is None), None
    )

    def _payload(attempt: ExamAttempt, attempts_used: int, resumed: bool) -> dict:
        remaining = 0
        if assignment.time_limit_minutes:
            elapsed = (datetime.now(timezone.utc) - attempt.started_at).total_seconds()
            remaining = max(0, (assignment.time_limit_minutes * 60) - int(elapsed))
        return {
            "attempt_id": attempt.id,
            "time_limit_minutes": assignment.time_limit_minutes,
            "remaining_seconds": remaining,
            "max_attempts": assignment.max_attempts,
            "attempts_used": attempts_used,
            "tab_switch_count": attempt.tab_switch_count,
            "is_flagged": attempt.is_flagged,
            "randomize_questions": assignment.randomize_questions,
            "show_results_after": assignment.show_results_after,
            "started_at": attempt.started_at.isoformat(),
            "resumed": resumed,
        }

    if active_attempt is not None:
        return _payload(active_attempt, len(existing_attempts), True)

    # No active session — enforce the completed-attempt limit.
    completed_count = len(
        [a for a in existing_attempts if a.submitted_at is not None]
    )
    if completed_count >= (assignment.max_attempts or 1):
        raise HTTPException(
            status_code=400, detail="Maximum attempts reached for this exam."
        )

    # Create new attempt (tab_switch_count defaults to 0 per-attempt).
    attempt = ExamAttempt(
        assignment_id=assignment_id,
        student_id=user.id,
    )
    db.add(attempt)
    await db.flush()
    return _payload(attempt, completed_count, False)


@router.post("/courses/{course_id}/assignments/{assignment_id}/exam/flag")
async def flag_exam_attempt(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Record a tab-switch / app-background event for anti-cheat tracking."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).get_course_with_access_check(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc

    result = await db.execute(
        select(ExamAttempt).where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == user.id,
            ExamAttempt.submitted_at.is_(None),  # active attempt only
        ).order_by(ExamAttempt.started_at.desc()).limit(1)
    )
    attempt = result.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="No active exam attempt found.")

    attempt.tab_switch_count += 1
    # Auto-flag after 3 switches
    if attempt.tab_switch_count >= 3 and not attempt.is_flagged:
        attempt.is_flagged = True
        attempt.flag_reason = f"Flagged: {attempt.tab_switch_count} tab switches detected."
    await db.flush()

    return {
        "tab_switch_count": attempt.tab_switch_count,
        "is_flagged": attempt.is_flagged,
        "message": "Attempt flagged for review." if attempt.is_flagged else "Tab switch recorded.",
    }


@router.post("/courses/{course_id}/assignments/{assignment_id}/exam/submit")
async def submit_exam_attempt(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Mark the active exam attempt as submitted."""
    assignment = await db.get(Assignment, assignment_id)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).get_course_with_access_check(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc

    result = await db.execute(
        select(ExamAttempt).where(
            ExamAttempt.assignment_id == assignment_id,
            ExamAttempt.student_id == user.id,
            ExamAttempt.submitted_at.is_(None),
        ).order_by(ExamAttempt.started_at.desc()).limit(1)
    )
    attempt = result.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="No active exam attempt found.")
    attempt.submitted_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Exam submitted successfully.", "submitted_at": attempt.submitted_at.isoformat()}


@router.get("/courses/{course_id}/assignments/{assignment_id}/exam/attempts")
async def list_exam_attempts(
    course_id: int,
    assignment_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Professor/admin: list all exam attempts with anti-cheat flags."""
    result = await db.execute(
        select(ExamAttempt)
        .where(ExamAttempt.assignment_id == assignment_id)
        .order_by(ExamAttempt.is_flagged.desc(), ExamAttempt.started_at.desc())
    )
    attempts = result.scalars().all()
    return [
        {
            "id": a.id,
            "student_id": a.student_id,
            "student_name": a.student.full_name if a.student else f"Student #{a.student_id}",
            "student_email": a.student.email if a.student else "",
            "started_at": a.started_at.isoformat(),
            "submitted_at": a.submitted_at.isoformat() if a.submitted_at else None,
            "tab_switch_count": a.tab_switch_count,
            "is_flagged": a.is_flagged,
            "flag_reason": a.flag_reason,
        }
        for a in attempts
    ]
