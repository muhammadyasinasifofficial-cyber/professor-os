"""ProfessorOS – Authentication service (login, register, lockout, tokens)."""

import asyncio
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import (
    create_access_token,
    create_email_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import User
from app.services.email_service import (
    send_password_reset_email,
    send_verification_email,
    send_welcome_email,
)
from app.services.registration_policy import registration_flags


class AuthService:
    """Handles all authentication logic."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.settings = get_settings()

    async def register(
        self, email: str, full_name: str, password: str, role: str = "student"
    ) -> Tuple[User, Optional[str], bool]:
        """
        Register a new user. Returns (user, verification_token, needs_approval).
        Raises ValueError if email already exists.
        """
        existing = await self.db.execute(
            select(User).where(User.email == email.lower())
        )
        if existing.scalar_one_or_none():
            raise ValueError("An account with this email already exists.")

        flags = registration_flags(role)
        needs_approval = flags["needs_approval"]

        user = User(
            email=email.lower(),
            full_name=full_name,
            hashed_password=hash_password(password),
            role=role,
            is_verified=flags["is_verified"],
            is_active=True,
            is_approved=not needs_approval,
        )
        self.db.add(user)
        await self.db.flush()

        token: Optional[str] = None
        if not flags["is_verified"]:
            token = create_email_token(user.email, purpose="verify")
            verify_url = f"{self.settings.BACKEND_URL}/auth/verify-email?token={token}"
            await asyncio.to_thread(send_verification_email, user.email, user.full_name, verify_url)

        return user, token, needs_approval

    async def login(self, email: str, password: str) -> Tuple[str, str]:
        """
        Authenticate user. Returns (access_token, refresh_token).
        Raises ValueError with descriptive messages for all failure cases.
        """
        user = await self._get_user_by_email(email)
        if not user:
            raise ValueError("No account found with this email address.")

        # Check verification first – no point in counting attempts for unverified users
        if not user.is_verified:
            raise ValueError("UNVERIFIED:Please verify your email before signing in.")

        # Check account suspension
        if not user.is_active:
            raise ValueError("Your account has been suspended. Contact your administrator.")

        # Check admin approval (professors / TAs)
        if not user.is_approved:
            raise ValueError("Your account is pending admin approval. You will be notified once approved.")

        # Check lockout
        if user.locked_until and user.locked_until > datetime.now(timezone.utc):
            remaining = (user.locked_until - datetime.now(timezone.utc)).seconds
            minutes = remaining // 60
            seconds = remaining % 60
            raise ValueError(
                f"Account is temporarily locked. Try again in {minutes}:{seconds:02d}."
            )

        # Verify password
        is_valid = await asyncio.to_thread(verify_password, password, user.hashed_password)
        if not is_valid:
            user.failed_attempts += 1
            if user.failed_attempts >= self.settings.MAX_LOGIN_ATTEMPTS:
                user.locked_until = datetime.now(timezone.utc) + timedelta(
                    minutes=self.settings.LOCKOUT_DURATION_MINUTES
                )
                user.failed_attempts = 0
                await self.db.flush()
                raise ValueError(
                    f"Too many failed attempts. Account locked for {self.settings.LOCKOUT_DURATION_MINUTES} minutes."
                )
            await self.db.flush()
            remaining_attempts = self.settings.MAX_LOGIN_ATTEMPTS - user.failed_attempts
            raise ValueError(
                f"Incorrect password. {remaining_attempts} attempt(s) remaining."
            )

        # Success – reset counters
        user.failed_attempts = 0
        user.locked_until = None
        await self.db.flush()

        access_token = create_access_token(user.id, user.role)
        refresh_token = create_refresh_token(user.id)
        return access_token, refresh_token

    async def refresh(self, refresh_token: str) -> str:
        """Issue a new access token from a valid refresh token."""
        payload = decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise ValueError("Invalid or expired refresh token.")

        user = await self.db.get(User, int(payload["sub"]))
        if not user or not user.is_active:
            raise ValueError("User not found or account suspended.")

        return create_access_token(user.id, user.role)

    async def verify_email(self, token: str) -> User:
        """Verify a user's email using the token from the verification link."""
        payload = decode_token(token)
        if not payload or payload.get("type") != "verify":
            raise ValueError("Invalid or expired verification link.")

        user = await self._get_user_by_email(payload["sub"])
        if not user:
            raise ValueError("User not found.")

        if user.is_verified:
            return user

        user.is_verified = True
        await self.db.flush()

        await asyncio.to_thread(send_welcome_email, user.email, user.full_name, user.role)
        return user

    async def forgot_password(self, email: str) -> Optional[str]:
        """Generate a password reset token (returns None if user not found, for security)."""
        user = await self._get_user_by_email(email)
        if not user:
            return None  # Don't reveal whether email exists

        token = create_email_token(user.email, purpose="reset")
        reset_url = f"{self.settings.BACKEND_URL}/auth/reset-password?token={token}"
        await asyncio.to_thread(send_password_reset_email, user.email, user.full_name, reset_url)

        return token

    async def reset_password(self, token: str, new_password: str) -> User:
        """Reset password using a valid reset token."""
        payload = decode_token(token)
        if not payload or payload.get("type") != "reset":
            raise ValueError("Invalid or expired reset link.")

        user = await self._get_user_by_email(payload["sub"])
        if not user:
            raise ValueError("User not found.")

        user.hashed_password = hash_password(new_password)
        user.failed_attempts = 0
        user.locked_until = None
        await self.db.flush()
        return user

    async def resend_verification(self, email: str) -> str:
        """Resend verification email. Returns the token."""
        user = await self._get_user_by_email(email)
        if not user:
            raise ValueError("No account found with this email.")
        if user.is_verified:
            raise ValueError("Email is already verified.")

        token = create_email_token(user.email, purpose="verify")
        verify_url = f"{self.settings.BACKEND_URL}/auth/verify-email?token={token}"
        await asyncio.to_thread(send_verification_email, user.email, user.full_name, verify_url)
        return token

    async def revoke_all_sessions(self, user_id: int) -> None:
        """Sign out from all devices by invalidating all tokens issued prior to now."""
        user = await self.db.get(User, user_id)
        if user:
            now = datetime.now(timezone.utc)
            user.updated_at = now
            user.token_valid_after = now
            await self.db.flush()

    # ── Private helpers ───────────────────────────────

    async def _get_user_by_email(self, email: str) -> Optional[User]:
        result = await self.db.execute(
            select(User).where(User.email == email.lower())
        )
        return result.scalar_one_or_none()
