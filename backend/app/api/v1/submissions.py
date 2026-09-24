"""ProfessorOS – Submission endpoints."""

from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.models.assignment import Assignment
from app.models.rubric import Rubric
from app.schemas.submission import (
    SubmissionCreate, SubmissionGrade, SubmissionResponse, SubmissionListResponse,
)
from app.services.submission_service import SubmissionService
from app.services.assignment_service import AssignmentService
from app.services.course_service import CourseService
from app.services.grading_pipeline import grade_submission_task, _grade_submission_core

router = APIRouter(tags=["Submissions"])
MAX_SUBMISSION_BYTES = 25 * 1024 * 1024


async def _verify_student_assignment(course_id: int, aid: int, user: User, db: AsyncSession) -> Assignment:
    assignment = await db.get(Assignment, aid)
    if not assignment or assignment.course_id != course_id:
        raise HTTPException(status_code=404, detail="Assignment not found.")
    try:
        await CourseService(db).get_course_with_access_check(course_id, user)
    except (ValueError, PermissionError) as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    return assignment


def _to_response(sub) -> SubmissionResponse:
    return SubmissionResponse(
        id=sub.id,
        assignment_id=sub.assignment_id,
        student_id=sub.student_id,
        student_name=sub.student.full_name if sub.student else None,
        student_email=sub.student.email if sub.student else None,
        submission_type=sub.submission_type,
        content=sub.content,
        file_name=sub.file_name,
        status=sub.status,
        score=sub.score,
        feedback=sub.feedback,
        graded_by_id=sub.graded_by_id,
        grader_name=sub.graded_by.full_name if sub.graded_by else None,
        submitted_at=sub.submitted_at,
        graded_at=sub.graded_at,
    )


# ── Student: submit assignment ─────────────────────────

@router.post(
    "/courses/{course_id}/assignments/{aid}/submissions",
    response_model=SubmissionResponse,
    status_code=201,
)
async def submit_assignment(
    course_id: int,
    aid: int,
    body: SubmissionCreate,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = SubmissionService(db)
    try:
        await _verify_student_assignment(course_id, aid, user, db)
        sub = await svc.submit(aid, user.id, body)
        return _to_response(sub)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/courses/{course_id}/assignments/{aid}/submissions/file",
    response_model=SubmissionResponse,
    status_code=201,
)
async def submit_file(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    await _verify_student_assignment(course_id, aid, user, db)
    content = await file.read(MAX_SUBMISSION_BYTES + 1)
    if len(content) > MAX_SUBMISSION_BYTES:
        raise HTTPException(status_code=413, detail="Submission file exceeds the 25 MB limit.")
    svc = SubmissionService(db)
    try:
        sub = await svc.save_file(aid, user.id, content, file.filename or "upload")
        return _to_response(sub)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ── Student: view own submission ───────────────────────

@router.get(
    "/courses/{course_id}/assignments/{aid}/submissions/me",
    response_model=SubmissionResponse,
)
async def get_my_submission(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    await _verify_student_assignment(course_id, aid, user, db)
    svc = SubmissionService(db)
    sub = await svc.get_my_submission(aid, user.id)
    if not sub:
        raise HTTPException(status_code=404, detail="No submission found.")
    return _to_response(sub)


# ── Prof/TA: list all submissions ─────────────────────

@router.get(
    "/courses/{course_id}/assignments/{aid}/submissions",
    response_model=SubmissionListResponse,
)
async def list_submissions(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = SubmissionService(db)
    try:
        assignment = await AssignmentService(db).verify_assignment_access(aid, user)
        if assignment.course_id != course_id:
            raise PermissionError("Assignment not found in this course.")
        subs = await svc.list_submissions(aid)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    items = [_to_response(s) for s in subs]
    pending = sum(1 for s in subs if s.status == "pending")
    graded = sum(1 for s in subs if s.status == "graded")
    return SubmissionListResponse(
        submissions=items,
        total=len(items),
        pending_count=pending,
        graded_count=graded,
    )


# ── Prof/TA: grade a submission ────────────────────────

@router.put("/submissions/{sid}/grade", response_model=SubmissionResponse)
async def grade_submission(
    sid: int,
    body: SubmissionGrade,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = SubmissionService(db)
    try:
        submission = await svc.get_submission(sid)
        await AssignmentService(db).verify_assignment_access(submission.assignment_id, user)
        sub = await svc.grade_submission(sid, body, user.id)
        return _to_response(sub)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ── Prof/TA: trigger AI rubric-anchored grading ───────

@router.post("/submissions/{sid}/ai-grade")
async def trigger_ai_grading(
    sid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    sync: bool = False,
):
    """Triggers rubric-anchored AI grading via DeepSeek-R1-Distill-70B on Groq."""
    svc = SubmissionService(db)
    submission = await svc.get_submission(sid)
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found.")

    try:
        await AssignmentService(db).verify_assignment_access(submission.assignment_id, user)
    except PermissionError as auth_err:
        raise HTTPException(status_code=403, detail=str(auth_err))

    assignment = await db.get(Assignment, submission.assignment_id)
    if not assignment:
        raise HTTPException(status_code=404, detail="Associated assignment not found.")

    # Fetch rubric criteria
    rubric_res = await db.execute(
        select(Rubric).where(Rubric.assignment_id == assignment.id).options(selectinload(Rubric.criteria))
    )
    rubric = rubric_res.scalar_one_or_none()

    criteria_data = []
    if rubric and rubric.criteria:
        for c in rubric.criteria:
            criteria_data.append({
                "name": c.name,
                "weight": c.weight,
                "max_score": (c.weight / 100.0) * float(assignment.max_marks or 100.0),
            })
    else:
        max_m = float(assignment.max_marks or 100.0)
        criteria_data = [
            {"name": "Technical Accuracy & Methodology", "weight": 50.0, "max_score": max_m * 0.5},
            {"name": "Completeness & Problem Resolution", "weight": 30.0, "max_score": max_m * 0.3},
            {"name": "Clarity & Academic Quality", "weight": 20.0, "max_score": max_m * 0.2},
        ]

    # Extract submission text content
    content = submission.content or ""
    if not content and submission.file_path:
        file_p = Path(submission.file_path)
        if file_p.exists() and file_p.suffix.lower() in [".txt", ".py", ".md", ".java", ".c", ".cpp"]:
            try:
                content = file_p.read_text(encoding="utf-8", errors="replace")
            except Exception:
                pass
    if not content:
        content = "Submission file received. (Binary or non-text document uploaded by student)."

    # Keep status pending while awaiting evaluation
    await db.commit()

    if sync:
        try:
            evaluation = _grade_submission_core(
                assignment_title=assignment.title,
                assignment_prompt=assignment.description or assignment.title,
                max_marks=float(assignment.max_marks or 100.0),
                rubric_criteria=criteria_data,
                student_submission_content=content,
                submission_type=submission.submission_type or "text",
            )
            submission.score = evaluation.total_score
            submission.feedback = evaluation.student_feedback
            submission.status = "graded"
            await db.commit()
            return {
                "status": submission.status,
                "mode": "synchronous",
                "submission_id": sid,
                "score": evaluation.total_score,
                "max_marks": evaluation.max_marks,
                "percentage": evaluation.percentage,
                "feedback": evaluation.student_feedback,
                "diagnostic_reasoning": evaluation.diagnostic_reasoning,
                "criteria": [c.model_dump() for c in evaluation.criteria_evaluations],
                "needs_review": evaluation.needs_review,
                "message": "AI grading completed successfully with DeepSeek-R1-Distill-70B.",
            }
        except Exception as e:
            logger.error("AI grading failed for submission %d: %s", sid, e, exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"AI grading failed: {str(e)}",
            )

    # Dispatch asynchronous background task to Celery
    task = grade_submission_task.delay(
        submission_id=submission.id,
        assignment_title=assignment.title,
        assignment_prompt=assignment.description or assignment.title,
        max_marks=float(assignment.max_marks or 100.0),
        rubric_criteria=criteria_data,
        student_submission_content=content,
        submission_type=submission.submission_type or "text",
    )

    return {
        "status": "queued",
        "mode": "asynchronous",
        "task_id": task.id,
        "submission_id": sid,
        "queue": "grading_normal",
        "evaluator_model": "deepseek-r1-distill-llama-70b",
        "message": "AI grading task successfully dispatched to Celery grading queue.",
    }


# ── Prof/TA: Batch AI grade all pending submissions ──

@router.post("/courses/{course_id}/assignments/{aid}/ai-grade-all")
async def batch_ai_grade_submissions(
    course_id: int,
    aid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Batch-evaluates all pending submissions for an assignment against the rubric."""
    try:
        assignment = await AssignmentService(db).verify_assignment_access(aid, user)
    except PermissionError as auth_err:
        raise HTTPException(status_code=403, detail=str(auth_err))

    # Fetch rubric criteria
    rubric_res = await db.execute(
        select(Rubric).where(Rubric.assignment_id == aid).options(selectinload(Rubric.criteria))
    )
    rubric = rubric_res.scalar_one_or_none()

    criteria_data = []
    max_m = float(assignment.max_marks or 100.0)
    if rubric and rubric.criteria:
        for c in rubric.criteria:
            criteria_data.append({
                "name": c.name,
                "weight": c.weight,
                "max_score": (c.weight / 100.0) * max_m,
            })
    else:
        criteria_data = [
            {"name": "Technical Accuracy & Methodology", "weight": 50.0, "max_score": max_m * 0.5},
            {"name": "Completeness & Problem Resolution", "weight": 30.0, "max_score": max_m * 0.3},
            {"name": "Clarity & Academic Quality", "weight": 20.0, "max_score": max_m * 0.2},
        ]

    # Find all pending submissions
    subs_res = await db.execute(
        select(Submission).where(
            Submission.assignment_id == aid,
            Submission.status == "pending",
        )
    )
    pending_subs = subs_res.scalars().all()
    if not pending_subs:
        return {"graded_count": 0, "message": "No pending submissions to grade."}

    graded_count = 0
    errors = []
    for sub in pending_subs:
        # Extract submission text content
        content = sub.content or ""
        if not content and sub.file_path:
            file_p = Path(sub.file_path)
            if file_p.exists() and file_p.suffix.lower() in [".txt", ".py", ".md", ".java", ".c", ".cpp"]:
                try:
                    content = file_p.read_text(encoding="utf-8", errors="replace")
                except Exception:
                    pass
        if not content:
            content = "Submission file received. (Binary or non-text document uploaded by student)."

        try:
            eval_res = _grade_submission_core(
                assignment_title=assignment.title,
                assignment_prompt=assignment.description or assignment.title,
                max_marks=max_m,
                rubric_criteria=criteria_data,
                student_submission_content=content,
                submission_type=sub.submission_type or "text",
            )
            sub.score = eval_res.total_score
            sub.feedback = eval_res.student_feedback
            sub.status = "graded"
            graded_count += 1
        except Exception as e:
            logger.error("Batch grading failed for submission %d: %s", sub.id, e)
            errors.append(f"Sub #{sub.id}: {str(e)}")

    await db.commit()
    return {
        "status": "completed",
        "graded_count": graded_count,
        "total_pending": len(pending_subs),
        "errors": errors,
        "message": f"Successfully auto-graded {graded_count} of {len(pending_subs)} submissions.",
    }


# ── Download submission file ───────────────────────────

@router.get("/submissions/{sid}/file")
async def download_submission_file(
    sid: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    from sqlalchemy import select
    from app.models.submission import Submission
    result = await db.execute(select(Submission).where(Submission.id == sid))
    sub = result.scalar_one_or_none()
    if not sub or not sub.file_path:
        raise HTTPException(status_code=404, detail="File not found.")
    
    # Students can only download their own files; profs/TAs can download any
    if user.role == "student" and sub.student_id != user.id:
        raise HTTPException(status_code=403, detail="Access denied.")
    
    if user.role in ("professor", "ta"):
        from app.models.assignment import Assignment
        from app.models.course import Course, Enrollment
        assignment = await db.get(Assignment, sub.assignment_id)
        if not assignment:
            raise HTTPException(status_code=404, detail="Assignment not found.")
        if user.role == "professor":
            course = await db.get(Course, assignment.course_id)
            if not course or course.professor_id != user.id:
                raise HTTPException(status_code=403, detail="Access denied.")
        elif user.role == "ta":
            enroll_res = await db.execute(
                select(Enrollment).where(
                    Enrollment.course_id == assignment.course_id,
                    Enrollment.user_id == user.id,
                    Enrollment.role == "ta"
                )
            )
            if not enroll_res.scalar_one_or_none():
                raise HTTPException(status_code=403, detail="Access denied.")
    path = Path(sub.file_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File missing from storage.")
    return FileResponse(str(path), filename=sub.file_name or path.name)
