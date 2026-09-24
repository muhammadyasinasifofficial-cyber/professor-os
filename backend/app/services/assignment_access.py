"""Authorization helpers for assignment-level professor/TA access."""


def can_access_assignment(
    *,
    user_role: str,
    user_id: int,
    assignment,
    delegated_ta_ids: set[int],
    enrolled_student_ids: set[int] | None = None,
) -> bool:
    role = getattr(user_role, "value", user_role)
    if role == "admin":
        return True
    if role == "professor":
        return assignment.course.professor_id == user_id
    if role == "ta":
        return user_id in delegated_ta_ids
    if role == "student":
        if enrolled_student_ids is not None:
            return user_id in enrolled_student_ids
        return False
    return False
