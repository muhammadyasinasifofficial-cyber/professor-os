"""ProfessorOS – Submission model."""

from datetime import datetime, timezone
from typing import Optional
import enum

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class SubmissionType(str, enum.Enum):
    TEXT = "text"
    FILE = "file"
    PROGRAMMING = "programming"
    MCQ = "mcq"


class SubmissionStatus(str, enum.Enum):
    PENDING = "pending"
    GRADED = "graded"


class Submission(Base):
    __tablename__ = "submissions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # ── Content ───────────────────────────────────────
    submission_type: Mapped[str] = mapped_column(
        Enum(SubmissionType, name="submission_type", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
        default=SubmissionType.TEXT.value,
    )
    content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # For text/programming/mcq
    file_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)  # For file submissions
    file_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)  # Original filename

    # ── Grading ───────────────────────────────────────
    status: Mapped[str] = mapped_column(
        Enum(SubmissionStatus, name="submission_status", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
        default=SubmissionStatus.PENDING.value,
    )
    score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    feedback: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    graded_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # ── Timestamps ────────────────────────────────────
    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    graded_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    evaluation_metadata: Mapped[Optional[str]] = mapped_column(
        Text, nullable=True
    )  # JSON blob of XAI grading data

    # ── Relationships ─────────────────────────────────
    assignment = relationship("Assignment", back_populates="submissions")
    student = relationship("User", foreign_keys=[student_id], lazy="selectin")
    graded_by = relationship("User", foreign_keys=[graded_by_id], lazy="selectin")

    def __repr__(self) -> str:
        return f"<Submission {self.id}: assignment={self.assignment_id} student={self.student_id} status={self.status}>"
