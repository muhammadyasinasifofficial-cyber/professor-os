import io
import pytest
import httpx
from unittest.mock import patch, MagicMock
from app.main import app
from app.core.security import create_access_token
from app.models.course import Course


@pytest.mark.asyncio
async def test_course_material_upload_resilience():
    """Verify course material upload endpoint succeeds even if Celery is offline."""
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Unauthenticated -> 401
        res = await client.post("/api/v1/courses/1/materials/ingest")
        assert res.status_code == 401

        # 2. Authenticated professor with mocked course access
        token = create_access_token(user_id=1, role="professor")
        headers = {"Authorization": f"Bearer {token}"}

        mock_course = MagicMock(spec=Course)
        mock_course.id = 1
        mock_course.professor_id = 1
        mock_course.enrollments = []

        with patch("app.services.course_service.CourseService.get_course_with_access_check", return_value=mock_course), \
             patch("app.api.v1.quizzes._process_course_document_background") as mock_bg, \
             patch("app.services.document_ingestion.ingest_course_document_task.delay", side_effect=Exception("Redis offline")):

            file_content = b"# Operating Systems Lecture 1\nProcess management concepts."
            files = {"file": ("lecture_01.md", io.BytesIO(file_content), "text/markdown")}

            upload_res = await client.post(
                "/api/v1/courses/1/materials/ingest",
                files=files,
                headers=headers,
            )

            assert upload_res.status_code == 202
            body = upload_res.json()
            assert body["status"] == "queued"
            assert "material_id" in body
            assert body["filename"] == "lecture_01.md"
