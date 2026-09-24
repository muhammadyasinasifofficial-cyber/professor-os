"""ProfessorOS – Auth endpoints (M-01)."""

import re
import time
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.dependencies import get_current_user
from app.db.base import get_db
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest, LoginRequest, MessageResponse, RefreshRequest,
    RegisterRequest, RegisterResponse, ResendVerificationRequest, ResetPasswordRequest, TokenResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])

# ── Simple in-memory email rate limiter (1 request per 60s per email) ─────────
_email_rate_limit: dict[str, float] = {}
_EMAIL_RATE_LIMIT_SECONDS = 60


def _check_email_rate_limit(email: str) -> None:
    """Raise 429 if the same email was used within the cooldown window."""
    now = time.monotonic()
    last = _email_rate_limit.get(email)
    if last and (now - last) < _EMAIL_RATE_LIMIT_SECONDS:
        remaining = int(_EMAIL_RATE_LIMIT_SECONDS - (now - last))
        raise HTTPException(
            status_code=429,
            detail=f"Too many requests. Please wait {remaining}s before trying again.",
        )
    _email_rate_limit[email] = now


def _validate_password_strength(password: str) -> None:
    """Enforce minimum password strength: 8 chars, at least 1 digit."""
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters long.")
    if not re.search(r"\d", password):
        raise HTTPException(status_code=400, detail="Password must contain at least one digit.")


@router.post("/register", response_model=RegisterResponse, status_code=201)
async def register(body: RegisterRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    _validate_password_strength(body.password)
    svc = AuthService(db)
    try:
        user, token, needs_approval = await svc.register(body.email, body.full_name, body.password, body.role)
        message = (
            "Registration successful. Your account is pending admin approval. You will be notified once approved."
            if needs_approval
            else "Registration successful. Check your email to verify your account."
        )
        return RegisterResponse(
            message=message,
            verification_token=token,
            approval_required=needs_approval,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    svc = AuthService(db)
    try:
        access, refresh = await svc.login(body.email, body.password)
        return TokenResponse(access_token=access, refresh_token=refresh)
    except ValueError as e:
        msg = str(e)
        if msg.startswith("UNVERIFIED:"):
            raise HTTPException(status_code=403, detail=msg.replace("UNVERIFIED:", ""))
        raise HTTPException(status_code=401, detail=msg)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: Annotated[AsyncSession, Depends(get_db)]):
    svc = AuthService(db)
    try:
        new_access = await svc.refresh(body.refresh_token)
        return TokenResponse(access_token=new_access, refresh_token=body.refresh_token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/logout", response_model=MessageResponse)
async def logout(
    request: Request,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
):
    token = None
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ")[1]
    if token:
        from app.core.security import decode_token
        payload = decode_token(token)
        if payload and payload.get("jti"):
            from app.services.cache_service import blacklist_token
            await blacklist_token(payload["jti"], ttl_seconds=3600)
    svc = AuthService(db)
    await svc.revoke_all_sessions(user.id)
    return MessageResponse(message="Logged out successfully.")


@router.get("/verify-email", response_model=MessageResponse)
async def verify_email(token: str = Query(...), db: AsyncSession = Depends(get_db)):
    svc = AuthService(db)
    try:
        await svc.verify_email(token)
        return MessageResponse(message="Email verified successfully. You can now sign in.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/resend-verification", response_model=MessageResponse)
async def resend_verification(
    body: ResendVerificationRequest, db: Annotated[AsyncSession, Depends(get_db)]
):
    _check_email_rate_limit(body.email.lower())
    svc = AuthService(db)
    try:
        await svc.resend_verification(body.email)
        return MessageResponse(message="Verification email sent.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    body: ForgotPasswordRequest, db: Annotated[AsyncSession, Depends(get_db)]
):
    _check_email_rate_limit(body.email.lower())
    svc = AuthService(db)
    await svc.forgot_password(body.email)
    return MessageResponse(message="If an account with that email exists, a reset link has been sent.")


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    body: ResetPasswordRequest, db: Annotated[AsyncSession, Depends(get_db)]
):
    _validate_password_strength(body.new_password)
    svc = AuthService(db)
    try:
        await svc.reset_password(body.token, body.new_password)
        return MessageResponse(message="Password updated successfully.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))



