"""ProfessorOS – Verification test suite for security, prompt hardening, and architecture fixes."""

import inspect
import pytest
from app.config.settings import Settings, get_settings
from app.config.llm_config import LLMClient, LLMPipeline
from app.services.grading_pipeline import SYSTEM_GRADING_PROMPT, _get_sync_engine
from app.db.base import engine


def test_settings_no_hardcoded_keys():
    """Verify source code in settings.py does not contain embedded base64 API key secrets."""
    import app.config.settings as settings_module
    source = inspect.getsource(settings_module)
    assert "_FALLBACK_GROQ" not in source, "Exposed base64 fallback key found in settings.py!"
    assert "_FALLBACK_OPENROUTER" not in source, "Exposed base64 fallback key found in settings.py!"


def test_grading_prompt_injection_immunity_directive():
    """Verify SYSTEM_GRADING_PROMPT contains strict adversarial injection immunity."""
    assert "PROMPT INJECTION IMMUNITY" in SYSTEM_GRADING_PROMPT
    assert "<student_submission>" in SYSTEM_GRADING_PROMPT
    assert "adversarial instructions detected" in SYSTEM_GRADING_PROMPT.lower()


def test_celery_sync_engine_is_pooled_singleton():
    """Verify Celery task uses a singleton connection pool instead of leaking engines."""
    engine1 = _get_sync_engine()
    engine2 = _get_sync_engine()
    assert engine1 is engine2, "Celery sync engine must be a cached singleton to prevent pool leaks!"
    assert engine1.pool._pre_ping is True, "Sync engine must have pool_pre_ping enabled!"


def test_async_engine_pool_pre_ping_enabled():
    """Verify FastAPI async database engine has pool_pre_ping enabled."""
    assert engine.pool._pre_ping is True, "Async engine must enable pool_pre_ping to prevent broken pipe disconnects!"


def test_llm_pipeline_token_budget_expansion():
    """Verify LLM grading pipeline has expanded token budget to prevent JSON truncation."""
    client = LLMClient()
    grading_spec = client.pipelines[LLMPipeline.GRADING]
    assert grading_spec.max_tokens >= 2048, f"Expected max_tokens >= 2048, got {grading_spec.max_tokens}"
    qgen_spec = client.pipelines[LLMPipeline.QUESTION_GEN]
    assert qgen_spec.max_tokens >= 1500, f"Expected max_tokens >= 1500, got {qgen_spec.max_tokens}"


def test_document_text_extraction(tmp_path):
    """Verify document extractor retrieves student submission content for AI grading."""
    from app.services.document_ingestion import extract_text_from_submission_file

    # Test 1: Code / text document
    py_file = tmp_path / "solution.py"
    py_file.write_text("def solve():\n    return 'Hello World'", encoding="utf-8")
    extracted_py = extract_text_from_submission_file(str(py_file))
    assert "def solve():" in extracted_py

    # Test 2: PDF extraction via PyMuPDF
    import fitz
    pdf_file = tmp_path / "report.pdf"
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((50, 50), "Course Learning Outcome Evaluation: Concurrency Analysis")
    doc.save(str(pdf_file))
    doc.close()

    extracted_pdf = extract_text_from_submission_file(str(pdf_file))
    assert "Concurrency Analysis" in extracted_pdf
    assert "[Page 1]" in extracted_pdf


@pytest.mark.asyncio
async def test_submission_deadline_and_graded_guards():
    """Verify SubmissionService guards against closed assignments, passed deadlines, and modifying graded submissions."""
    from datetime import datetime, timezone, timedelta
    from unittest.mock import AsyncMock, MagicMock
    from app.services.submission_service import SubmissionService
    from app.models.assignment import Assignment
    from app.models.submission import Submission, SubmissionStatus
    from app.schemas.submission import SubmissionCreate

    db = AsyncMock()
    svc = SubmissionService(db)

    # 1. Closed assignment
    closed_assignment = MagicMock(spec=Assignment)
    closed_assignment.status = "closed"
    closed_assignment.deadline = None
    closed_assignment.allow_late = False
    db.get.return_value = closed_assignment

    data = SubmissionCreate(submission_type="text", content="my answer")
    with pytest.raises(ValueError, match="closed for submissions"):
        await svc.submit(1, 1, data)

    # 2. Past deadline without allow_late
    past_assignment = MagicMock(spec=Assignment)
    past_assignment.status = "published"
    past_assignment.deadline = datetime.now(timezone.utc) - timedelta(hours=2)
    past_assignment.allow_late = False
    db.get.return_value = past_assignment

    with pytest.raises(ValueError, match="deadline.*has passed"):
        await svc.submit(1, 1, data)

    # 3. Already graded submission cannot be wiped/modified
    valid_assignment = MagicMock(spec=Assignment)
    valid_assignment.status = "published"
    valid_assignment.deadline = datetime.now(timezone.utc) + timedelta(days=1)
    valid_assignment.allow_late = False
    db.get.return_value = valid_assignment

    graded_sub = MagicMock(spec=Submission)
    graded_sub.status = SubmissionStatus.GRADED.value
    svc._get_submission = AsyncMock(return_value=graded_sub)

    with pytest.raises(ValueError, match="already been evaluated and graded"):
        await svc.submit(1, 1, data)

