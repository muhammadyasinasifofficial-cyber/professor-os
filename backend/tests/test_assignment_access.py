from types import SimpleNamespace

from app.services.assignment_access import can_access_assignment


def test_ta_can_access_only_an_assignment_delegated_to_them():
    assignment = SimpleNamespace(course=SimpleNamespace(professor_id=10))

    assert can_access_assignment(
        user_role="ta",
        user_id=22,
        assignment=assignment,
        delegated_ta_ids={22},
    ) is True
    assert can_access_assignment(
        user_role="ta",
        user_id=23,
        assignment=assignment,
        delegated_ta_ids={22},
    ) is False


def test_course_professor_and_admin_can_access_any_assignment():
    assignment = SimpleNamespace(course=SimpleNamespace(professor_id=10))

    assert can_access_assignment(
        user_role="professor", user_id=10, assignment=assignment, delegated_ta_ids=set()
    ) is True
    assert can_access_assignment(
        user_role="admin", user_id=999, assignment=assignment, delegated_ta_ids=set()
    ) is True


def test_student_can_access_only_if_enrolled():
    assignment = SimpleNamespace(course=SimpleNamespace(professor_id=10))

    assert can_access_assignment(
        user_role="student",
        user_id=101,
        assignment=assignment,
        delegated_ta_ids=set(),
        enrolled_student_ids={101, 102},
    ) is True
    assert can_access_assignment(
        user_role="student",
        user_id=999,
        assignment=assignment,
        delegated_ta_ids=set(),
        enrolled_student_ids={101, 102},
    ) is False
