"""ProfessorOS – FastAPI dependencies (auth, DB session, role guards)."""

from typing import Annotated, List

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.base import get_db
from app.models.user import User

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    token_bearer: Annotated[str, Depends(_bearer)] = None,
) -> User:
    """Extract and validate the current user from the Authorization header or query params."""
    token = None
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ")[1]
    else:
        token = request.query_params.get("token")

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
        )

    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
        )

    # Check token blacklist (e.g. from logout)
    jti = payload.get("jti")
    if jti:
        from app.services.cache_service import is_token_blacklisted
        if await is_token_blacklisted(jti):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has been revoked.",
            )

    user_id = int(payload["sub"])
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found.",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account has been suspended.",
        )

    # Invalidate tokens issued prior to a session revocation event
    token_valid_after = getattr(user, "token_valid_after", None)
    if token_valid_after and payload.get("iat"):
        from datetime import datetime, timezone
        raw_iat = payload["iat"]
        iat_dt = (
            datetime.fromtimestamp(raw_iat, tz=timezone.utc)
            if isinstance(raw_iat, (int, float))
            else raw_iat
        )
        if iat_dt < token_valid_after:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session has been revoked. Please sign in again.",
            )

    return user


def require_roles(*roles: str):
    """Dependency factory: restrict access to specific roles."""

    async def _guard(
        user: Annotated[User, Depends(get_current_user)],
    ) -> User:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of: {', '.join(roles)}.",
            )
        return user

    return _guard
