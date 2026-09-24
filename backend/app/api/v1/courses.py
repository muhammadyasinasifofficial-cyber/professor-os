"""ProfessorOS – Course endpoints (M-02)."""

import asyncio
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.llm_config import get_llm_client, LLMPipeline
from app.core.dependencies import get_current_user, require_roles
from app.db.base import get_db
from app.models.user import User
from app.schemas.course import (
    CLOCreate, CLOResponse, CourseCreate, CourseListResponse, CourseResponse,
    CourseUpdate, EnrollRequest, EnrollmentResponse, CourseJoinRequest,
    CourseChatRequest, CourseChatResponse, SourceReference,
)
from app.services.course_service import CourseService
from app.services.document_ingestion import DoclingPipeline
from app.services.intent_router import LocalIntentRouter, get_intent_router

router = APIRouter(prefix="/courses", tags=["Courses"])


@router.get("", response_model=CourseListResponse)
async def list_courses(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    courses = await svc.list_courses(user)
    items = []
    for c in courses:
        resp = CourseResponse.model_validate(c)
        resp.professor_name = c.professor.full_name if c.professor else None
        resp.enrollment_count = len(c.enrollments) if c.enrollments else 0
        resp.assignment_count = len(c.assignments) if c.assignments else 0
        items.append(resp)
    return CourseListResponse(courses=items, total=len(items))


@router.post("", response_model=CourseResponse, status_code=201)
async def create_course(
    body: CourseCreate,
    user: Annotated[User, Depends(require_roles("admin", "professor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        prof_id = user.id if user.role == "professor" else (body.professor_id or user.id)
        course = await svc.create_course(body, prof_id)
        return CourseResponse.model_validate(course)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{course_id}", response_model=CourseResponse)
async def get_course(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        course = await svc.get_course_with_access_check(course_id, user)
        resp = CourseResponse.model_validate(course)
        resp.professor_name = course.professor.full_name if course.professor else None
        resp.enrollment_count = len(course.enrollments) if course.enrollments else 0
        resp.assignment_count = len(course.assignments) if course.assignments else 0
        return resp
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.put("/{course_id}", response_model=CourseResponse)
async def update_course(
    course_id: int, body: CourseUpdate,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        course = await svc.update_course(course_id, body, user)
        return CourseResponse.model_validate(course)
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


@router.delete("/{course_id}")
async def archive_course(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        await svc.archive_course(course_id, user)
        return {"message": "Course archived."}
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.delete("/{course_id}/permanent")
async def delete_course_permanently(
    course_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Permanently delete a course and its related academic records."""
    svc = CourseService(db)
    try:
        await svc.delete_course(course_id, user)
        return {"message": "Course permanently deleted."}
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


# ── Enrollment ────────────────────────────────────────

@router.get("/{course_id}/enrollments", response_model=list[EnrollmentResponse])
async def list_enrollments(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        # Verify access - only professor owner or admin can list enrollments
        await svc.verify_course_management_access(course_id, user)
        enrollments = await svc.list_enrollments(course_id)
        items = []
        for e in enrollments:
            resp = EnrollmentResponse.model_validate(e)
            resp.user_name = e.user.full_name if e.user else None
            resp.user_email = e.user.email if e.user else None
            items.append(resp)
        return items
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/{course_id}/enroll", response_model=EnrollmentResponse, status_code=201)
async def enroll_user(
    course_id: int, body: EnrollRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        # Verify access - only course professor or admin can enroll users
        await svc.verify_course_management_access(course_id, user)
        user_id = body.user_id
        if user_id is None and body.email:
            from sqlalchemy import select
            lookup = await db.execute(
                select(User).where(User.email == body.email.strip().lower())
            )
            account = lookup.scalar_one_or_none()
            if not account:
                raise ValueError("No user account was found for that email.")
            user_id = account.id
        if user_id is None:
            raise ValueError("Provide a user id or email.")
        enrollment = await svc.enroll_user(course_id, user_id, body.role)
        resp = EnrollmentResponse.model_validate(enrollment)
        resp.user_name = enrollment.user.full_name if enrollment.user else None
        resp.user_email = enrollment.user.email if enrollment.user else None
        return resp
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/join", response_model=EnrollmentResponse, status_code=201)
async def join_course(
    body: CourseJoinRequest,
    user: Annotated[User, Depends(require_roles("student"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        enrollment = await svc.join_course(user.id, body.join_code)
        resp = EnrollmentResponse.model_validate(enrollment)
        resp.user_name = user.full_name
        resp.user_email = user.email
        return resp
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{course_id}/enroll/{uid}")
async def remove_enrollment(
    course_id: int, uid: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        # Verify access - only course professor or admin can remove enrollments
        await svc.verify_course_management_access(course_id, user)
        await svc.remove_enrollment(course_id, uid)
        return {"message": "Enrollment removed."}
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/{course_id}/enroll/csv")
async def enroll_csv(
    course_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
    file: UploadFile = File(...),
):
    svc = CourseService(db)
    try:
        # Verify access - only course professor or admin can bulk enroll
        await svc.verify_course_management_access(course_id, user)
        content = await file.read()
        return await svc.import_enrollments_csv(course_id, content)
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


# ── CLOs ──────────────────────────────────────────────

@router.get("/{course_id}/clos", response_model=list[CLOResponse])
async def list_clos(
    course_id: int,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        # Verify access - only enrolled users or course management can view CLOs
        await svc.get_course_with_access_check(course_id, user)
        clos = await svc.list_clos(course_id)
        return [CLOResponse.model_validate(c) for c in clos]
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/{course_id}/clos", response_model=CLOResponse, status_code=201)
async def create_clo(
    course_id: int, body: CLOCreate,
    user: Annotated[User, Depends(require_roles("professor", "admin", "ta"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        # Verify access - only course professor or admin can create CLOs
        await svc.verify_course_management_access(course_id, user)
        clo = await svc.create_clo(course_id, body.code, body.description)
        return CLOResponse.model_validate(clo)
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


@router.delete("/{course_id}/clos/{clo_id}")
async def delete_clo(
    course_id: int, clo_id: int,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    svc = CourseService(db)
    try:
        # Verify access - only course professor or admin can delete CLOs
        await svc.verify_course_management_access(course_id, user)
        await svc.delete_clo(course_id, clo_id)
        return {"message": "CLO deleted."}
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 404
        raise HTTPException(status_code=code, detail=str(e))


@router.post("/{course_id}/ta", response_model=EnrollmentResponse, status_code=201)
async def delegate_ta(
    course_id: int, body: EnrollRequest,
    user: Annotated[User, Depends(require_roles("professor", "admin"))],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Delegate TA role to a user for a course."""
    svc = CourseService(db)
    try:
        # Verify access - only course professor or admin can delegate TA role
        await svc.verify_course_management_access(course_id, user)
        enrollment = await svc.enroll_user(course_id, body.user_id, role="ta")
        resp = EnrollmentResponse.model_validate(enrollment)
        resp.user_name = enrollment.user.full_name if enrollment.user else None
        resp.user_email = enrollment.user.email if enrollment.user else None
        return resp
    except (ValueError, PermissionError) as e:
        code = 403 if isinstance(e, PermissionError) else 400
        raise HTTPException(status_code=code, detail=str(e))


# ── Course Chat (M-09 RAG) ───────────────────────────

@router.post("/{course_id}/chat", response_model=CourseChatResponse)
async def chat_with_course(
    course_id: int,
    body: CourseChatRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """M-09: AI Teaching Assistant (RAG Chatbot).

    Allows enrolled students, TAs, and professors to ask questions grounded in course materials.
    Uses LocalIntentRouter for fast semantic categorization and Docling/FAISS vector retrieval.
    """
    svc = CourseService(db)
    try:
        course = await svc.get_course_with_access_check(course_id, user)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

    # 1. Local Semantic Intent Routing (< 35ms)
    intent_detected = "COURSE_QA"
    try:
        router_svc = get_intent_router()
        routing_res = router_svc.route(body.message)
        intent_detected = routing_res.intent.value
    except Exception:
        pass

    # 2. Vector Semantic Search over course materials
    pipeline = DoclingPipeline(course_id=course_id)
    chunks = await asyncio.to_thread(pipeline.search, body.message, 3)

    sources: list[SourceReference] = []
    context_blocks: list[str] = []
    for c in chunks:
        src = c.get("source_file", "Course Materials")
        txt = c.get("text", "")
        cid = c.get("chunk_id")
        score = c.get("score")
        context_blocks.append(f"--- Document: {src} (Chunk {cid}) ---\n{txt}")
        sources.append(SourceReference(
            source=src,
            chunk_id=cid,
            text=txt[:250] + ("..." if len(txt) > 250 else ""),
            score=round(score, 4) if score is not None else None,
        ))

    context_str = "\n\n".join(context_blocks) if context_blocks else "No specific course materials found for this query."

    # 3. Formulate prompt for LLMPipeline.RAG
    system_prompt = (
        f"You are the AI Teaching Assistant for the course '{course.title}' ({course.code}).\n"
        "Your role is to explain concepts clearly, accurately, and pedagogically.\n"
        "Base your explanations primarily on the provided course lecture materials whenever available.\n"
        "If quoting or referencing concepts from the documents, clearly indicate the document source.\n"
        "Maintain a helpful, scholarly, and supportive tone."
    )
    user_prompt = (
        f"Course Materials Context:\n{context_str}\n\n"
        f"Student Question: {body.message}\n\n"
        "Provide a clear, detailed, and directly helpful answer to the student's question."
    )

    llm = get_llm_client()
    try:
        reply_text = await llm.acomplete(
            pipeline=LLMPipeline.RAG,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.2,
        )
    except Exception as e:
        import logging
        logging.getLogger("professor_os.chat").exception("Course chat failed", exc_info=e)
        if chunks:
            top_chunk = chunks[0]
            src_file = top_chunk.get("source_file", "Course Materials")
            reply_text = (
                f"Based on your course materials in {src_file}:\n\n"
                f"{top_chunk.get('text', '')}\n\n"
                "(Note: Cloud AI generation is currently operating in direct retrieval mode. Full synthesis will be active momentarily.)"
            )
        else:
            reply_text = (
                f"I searched the indexed course materials for '{course.title}', but could not find a direct section matching your question. "
                "Please make sure your instructor has uploaded the relevant lecture slides or notes under Course Materials, or try rephrasing your question."
            )

    return CourseChatResponse(
        response=reply_text,
        sources=sources,
        session_id=body.session_id,
        intent=intent_detected,
        course_id=course_id,
    )

