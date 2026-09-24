"""ProfessorOS – Assignment model."""

from datetime import datetime, timezone
from typing import Optional, List
import enum

from sqlalchemy import (
    Boolean, Column, DateTime, Enum, Float, ForeignKey, Integer, String, Table, Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class AssignmentType(str, enum.Enum):
    TEXT = "text"
    FILE = "file"
    MCQ = "mcq"
    PROGRAMMING = "programming"


class AssignmentStatus(str, enum.Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    CLOSED = "closed"


# ── Many-to-many: Assignment ↔ CLO ────────────────────
assignment_clo_table = Table(
    "assignment_clos",
    Base.metadata,
    Column("assignment_id", ForeignKey("assignments.id", ondelete="CASCADE"), primary_key=True),
    Column("clo_id", ForeignKey("clos.id", ondelete="CASCADE"), primary_key=True),
)

# ── Many-to-many: Assignment ↔ TA delegation ─────────
assignment_ta_table = Table(
    "assignment_tas",
    Base.metadata,
    Column("assignment_id", ForeignKey("assignments.id", ondelete="CASCADE"), primary_key=True),
    Column("user_id", ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("batch_size", Integer, nullable=True),  # None = all submissions
)


class Assignment(Base):
    __tablename__ = "assignments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # Rich text (Quill delta JSON)
    type: Mapped[str] = mapped_column(
        Enum(AssignmentType, name="assignment_type", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        Enum(AssignmentStatus, name="assignment_status", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
        default=AssignmentStatus.DRAFT.value,
    )

    max_marks: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)
    deadline: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # ── Late submission rules ─────────────────────────
    allow_late: Mapped[bool] = mapped_column(Boolean, default=False)
    late_penalty_per_day: Mapped[float] = mapped_column(Float, default=0.0)
    max_penalty_cap: Mapped[float] = mapped_column(Float, default=100.0)

    # ── Exam / Timed Assessment ────────────────────────
    time_limit_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # None = no limit
    max_attempts: Mapped[int] = mapped_column(Integer, default=1)
    randomize_questions: Mapped[bool] = mapped_column(Boolean, default=False)
    show_results_after: Mapped[bool] = mapped_column(Boolean, default=True)

    # ── Timestamps ────────────────────────────────────
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # ── Relationships ─────────────────────────────────
    course = relationship("Course", back_populates="assignments")
    rubric: Mapped[Optional["Rubric"]] = relationship(
        "Rubric", back_populates="assignment", uselist=False, lazy="selectin", cascade="all, delete-orphan"
    )
    clos = relationship("CLO", secondary=assignment_clo_table, lazy="selectin")
    submissions = relationship("Submission", back_populates="assignment", lazy="selectin", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Assignment {self.id}: {self.title} ({self.type})>"
