"""ProfessorOS – Submission schemas."""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, Field


class SubmissionCreate(BaseModel):
    submission_type: str = Field(..., pattern="^(text|file|programming|mcq)$")
    content: Optional[str] = None  # For text/programming/mcq


class SubmissionGrade(BaseModel):
    score: float = Field(..., ge=0, le=100)
    feedback: Optional[str] = None


class SubmissionResponse(BaseModel):
    id: int
    assignment_id: int
    student_id: int
    student_name: Optional[str] = None
    student_email: Optional[str] = None
    submission_type: str
    content: Optional[str] = None
    file_name: Optional[str] = None
    status: str
    score: Optional[float] = None
    feedback: Optional[str] = None
    graded_by_id: Optional[int] = None
    grader_name: Optional[str] = None
    submitted_at: datetime
    graded_at: Optional[datetime] = None
    evaluation_metadata: Optional[str] = None  # JSON blob of XAI grading data

    model_config = {"from_attributes": True}


class SubmissionListResponse(BaseModel):
    submissions: List[SubmissionResponse]
    total: int
    pending_count: int
    graded_count: int
