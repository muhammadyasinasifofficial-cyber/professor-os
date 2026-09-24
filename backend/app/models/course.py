"""ProfessorOS – Course, CLO, and Enrollment models."""

from datetime import datetime, timezone
from typing import Optional, List

from sqlalchemy import (
    Boolean, DateTime, Float, ForeignKey, Integer, String, Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


import secrets

def generate_join_code() -> str:
    return secrets.token_hex(3).upper()


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    code: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    join_code: Mapped[str] = mapped_column(String(10), nullable=True, unique=True, index=True, default=generate_join_code)
    semester: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    at_risk_threshold: Mapped[float] = mapped_column(Float, default=40.0)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False)

    # ── HEC Assessment Weightage ──────────────────────
    quiz_weight: Mapped[int] = mapped_column(Integer, default=20)
    assignment_weight: Mapped[int] = mapped_column(Integer, default=20)
    midterm_weight: Mapped[int] = mapped_column(Integer, default=20)
    final_weight: Mapped[int] = mapped_column(Integer, default=40)

    # ── Foreign Keys ──────────────────────────────────
    professor_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)

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
    professor = relationship("User", back_populates="courses_owned", lazy="selectin")
    enrollments: Mapped[List["Enrollment"]] = relationship(
        back_populates="course", lazy="selectin", cascade="all, delete-orphan"
    )
    clos: Mapped[List["CLO"]] = relationship(back_populates="course", lazy="selectin", cascade="all, delete-orphan")
    assignments: Mapped[List["Assignment"]] = relationship(
        "Assignment", back_populates="course", lazy="selectin", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Course {self.id}: {self.code} – {self.title}>"


class CLO(Base):
    """Course Learning Outcome – HEC requires assignments to link to at least one."""
    __tablename__ = "clos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    code: Mapped[str] = mapped_column(String(20), nullable=False)  # e.g., "CLO-1"
    description: Mapped[str] = mapped_column(Text, nullable=False)

    # ── Relationships ─────────────────────────────────
    course = relationship("Course", back_populates="clos", lazy="selectin")

    def __repr__(self) -> str:
        return f"<CLO {self.code}: {self.description[:40]}>"


class Enrollment(Base):
    __tablename__ = "enrollments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role: Mapped[str] = mapped_column(String(20), nullable=False, default="student")  # "student" or "ta"
    enrolled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # ── Relationships ─────────────────────────────────
    course = relationship("Course", back_populates="enrollments", lazy="selectin")
    user = relationship("User", back_populates="enrollments", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Enrollment user={self.user_id} course={self.course_id} role={self.role}>"
