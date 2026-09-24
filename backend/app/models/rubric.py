"""ProfessorOS – Rubric, RubricCriterion, and RubricLevel models."""

from typing import List, Optional
import enum

from sqlalchemy import Enum, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class LevelName(str, enum.Enum):
    EXCELLENT = "excellent"
    SATISFACTORY = "satisfactory"
    DEVELOPING = "developing"
    INSUFFICIENT = "insufficient"


class Rubric(Base):
    """A rubric belongs to exactly one assignment."""
    __tablename__ = "rubrics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("assignments.id", ondelete="CASCADE"), nullable=False, unique=True, index=True
    )

    # ── Relationships ─────────────────────────────────
    assignment = relationship("Assignment", back_populates="rubric")
    criteria: Mapped[List["RubricCriterion"]] = relationship(
        back_populates="rubric", lazy="selectin", cascade="all, delete-orphan",
        order_by="RubricCriterion.order",
    )

    def __repr__(self) -> str:
        return f"<Rubric {self.id} for assignment {self.assignment_id}>"


class RubricCriterion(Base):
    """A single criterion row in a rubric (min 3, max 10)."""
    __tablename__ = "rubric_criteria"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    rubric_id: Mapped[int] = mapped_column(ForeignKey("rubrics.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    weight: Mapped[float] = mapped_column(Float, nullable=False)  # Must sum to 100 across all criteria
    order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # ── Relationships ─────────────────────────────────
    rubric = relationship("Rubric", back_populates="criteria")
    levels: Mapped[List["RubricLevel"]] = relationship(
        back_populates="criterion", lazy="selectin", cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<RubricCriterion {self.id}: {self.name} ({self.weight}%)>"


class RubricLevel(Base):
    """Performance level description for a criterion (exactly 4 per criterion)."""
    __tablename__ = "rubric_levels"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    criterion_id: Mapped[int] = mapped_column(ForeignKey("rubric_criteria.id", ondelete="CASCADE"), nullable=False, index=True)
    level: Mapped[str] = mapped_column(
        Enum(LevelName, name="level_name", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
    )
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")

    # ── Relationships ─────────────────────────────────
    criterion = relationship("RubricCriterion", back_populates="levels")

    def __repr__(self) -> str:
        return f"<RubricLevel {self.level} for criterion {self.criterion_id}>"
