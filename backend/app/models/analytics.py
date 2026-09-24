"""ProfessorOS – Analytics models (snapshots + at-risk records)."""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class AnalyticsSnapshot(Base):
    """Pre-computed analytics for a course (or specific assignment)."""
    __tablename__ = "analytics_snapshots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    assignment_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("assignments.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # ── Computed statistics ───────────────────────────
    mean: Mapped[float] = mapped_column(Float, default=0.0)
    median: Mapped[float] = mapped_column(Float, default=0.0)
    std_dev: Mapped[float] = mapped_column(Float, default=0.0)
    total_students: Mapped[int] = mapped_column(Integer, default=0)

    # ── Distribution buckets (JSON): {"0-20": 5, "21-40": 12, ...}
    dist_buckets: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # ── Average score per rubric criterion (JSON): {"Criterion Name": 78.5, ...}
    criterion_scores: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # ── HEC quality grade ─────────────────────────────
    hec_grade: Mapped[Optional[str]] = mapped_column(String(1), nullable=True)  # W, X, Y, Z

    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    def __repr__(self) -> str:
        return f"<AnalyticsSnapshot course={self.course_id} mean={self.mean:.1f}>"


class AtRiskRecord(Base):
    """Records of students flagged as at-risk in a course."""
    __tablename__ = "at_risk_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reason: Mapped[str] = mapped_column(String(100), nullable=False)  # e.g., "Low Participation", "Inactive 7 Days"
    average_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    last_submission: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    detected_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # ── Relationships ─────────────────────────────────
    student = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return f"<AtRiskRecord student={self.student_id} course={self.course_id} reason={self.reason}>"
