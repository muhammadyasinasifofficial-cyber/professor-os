"""ProfessorOS – Analytics service (grade stats, at-risk detection, HEC grade)."""

import statistics
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.analytics import AnalyticsSnapshot, AtRiskRecord
from app.models.course import Course, Enrollment


HEC_GRADES = {
    "W": {"min": 80, "label": "World Class"},
    "X": {"min": 60, "label": "Acceptable"},
    "Y": {"min": 40, "label": "Needs Improvement"},
    "Z": {"min": 0, "label": "Below Standard"},
}


def compute_hec_grade(average_score: float) -> tuple:
    """Returns (grade_letter, label) based on average score."""
    for grade, info in HEC_GRADES.items():
        if average_score >= info["min"]:
            return grade, info["label"]
    return "Z", "Below Standard"


class AnalyticsService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def compute_analytics(self, course_id: int, scores: List[float]) -> AnalyticsSnapshot:
        """Compute and store analytics snapshot from a list of scores."""
        await self.db.execute(delete(AnalyticsSnapshot).where(AnalyticsSnapshot.course_id == course_id))
        
        if not scores:
            snapshot = AnalyticsSnapshot(
                course_id=course_id, mean=0, median=0, std_dev=0,
                total_students=0, dist_buckets={}, criterion_scores={},
                hec_grade=None,
            )
            self.db.add(snapshot)
            await self.db.flush()
            return snapshot

        mean = statistics.mean(scores)
        median = statistics.median(scores)
        std_dev = statistics.stdev(scores) if len(scores) > 1 else 0.0

        # Distribution buckets
        buckets = {"0-20": 0, "21-40": 0, "41-60": 0, "61-80": 0, "81-100": 0}
        for score in scores:
            if score <= 20:
                buckets["0-20"] += 1
            elif score <= 40:
                buckets["21-40"] += 1
            elif score <= 60:
                buckets["41-60"] += 1
            elif score <= 80:
                buckets["61-80"] += 1
            else:
                buckets["81-100"] += 1

        grade, label = compute_hec_grade(mean)

        snapshot = AnalyticsSnapshot(
            course_id=course_id, mean=round(mean, 2), median=round(median, 2),
            std_dev=round(std_dev, 2), total_students=len(scores),
            dist_buckets=buckets, criterion_scores={}, hec_grade=grade,
        )
        self.db.add(snapshot)
        await self.db.flush()
        return snapshot

    async def get_latest_snapshot(self, course_id: int) -> Optional[AnalyticsSnapshot]:
        result = await self.db.execute(
            select(AnalyticsSnapshot)
            .where(AnalyticsSnapshot.course_id == course_id)
            .order_by(AnalyticsSnapshot.computed_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def detect_at_risk_students(
        self, course_id: int, threshold: float,
        student_scores: Dict[int, float],
    ) -> List[AtRiskRecord]:
        """Flag students below the at-risk threshold."""
        records = []
        for student_id, avg_score in student_scores.items():
            reasons = []
            if avg_score < threshold:
                reasons.append("Low Average")
            if reasons:
                # Remove prior records for this student in this course
                await self.db.execute(
                    delete(AtRiskRecord).where(
                        AtRiskRecord.course_id == course_id,
                        AtRiskRecord.student_id == student_id,
                    )
                )
                record = AtRiskRecord(
                    course_id=course_id, student_id=student_id,
                    reason=", ".join(reasons), average_score=avg_score,
                )
                self.db.add(record)
                records.append(record)
        await self.db.flush()
        return records

    async def get_at_risk_students(self, course_id: int) -> List[AtRiskRecord]:
        result = await self.db.execute(
            select(AtRiskRecord)
            .options(selectinload(AtRiskRecord.student))
            .where(AtRiskRecord.course_id == course_id)
            .order_by(AtRiskRecord.detected_at.desc())
        )
        all_records = result.scalars().all()
        seen_students = set()
        deduped = []
        for r in all_records:
            if r.student_id not in seen_students:
                seen_students.add(r.student_id)
                deduped.append(r)
        return deduped

    async def compute_analytics_from_db(self, course_id: int) -> Optional[AnalyticsSnapshot]:
        """Compute analytics from actual graded submission scores stored in the DB, normalized by max_marks."""
        from sqlalchemy import text
        score_result = await self.db.execute(
            text(
                "SELECT s.score, a.max_marks, s.student_id FROM submissions s "
                "JOIN assignments a ON a.id = s.assignment_id "
                "WHERE a.course_id = :cid AND s.status = 'graded' AND s.score IS NOT NULL"
            ),
            {"cid": course_id},
        )
        rows = score_result.fetchall()
        scores = []
        student_scores_map: Dict[int, List[float]] = {}
        for r in rows:
            raw_score = float(r[0])
            max_m = float(r[1]) if r[1] and float(r[1]) > 0 else 100.0
            pct = min(100.0, max(0.0, (raw_score / max_m) * 100.0))
            scores.append(round(pct, 2))
            sid = int(r[2])
            student_scores_map.setdefault(sid, []).append(pct)

        snapshot = await self.compute_analytics(course_id, scores)

        # Detect at-risk students using student course average across assignments
        student_scores = {
            sid: round(statistics.mean(pct_list), 2)
            for sid, pct_list in student_scores_map.items()
        }

        from app.models.course import Course
        course = await self.db.get(Course, course_id)
        threshold = course.at_risk_threshold if course else 50.0
        if student_scores:
            await self.detect_at_risk_students(course_id, threshold, student_scores)

        return snapshot

