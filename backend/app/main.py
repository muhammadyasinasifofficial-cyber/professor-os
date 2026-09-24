"""ProfessorOS – FastAPI application entry point."""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.core.config import get_settings
from app.db.base import engine, Base

# Import all models so SQLAlchemy knows about them
from app.models import user, course, assignment, rubric, analytics, submission  # noqa: F401

STATIC_DIR = Path(__file__).parent.parent / "static"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """On startup: ensure all tables exist and safely run minor migrations."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        
        # Auto-migration for join_code column
        try:
            from sqlalchemy import text
            res = await conn.execute(
                text("SELECT column_name FROM information_schema.columns WHERE table_name='courses' AND column_name='join_code'")
            )
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE courses ADD COLUMN join_code VARCHAR(10)"))
                
                # Generate unique codes for any existing courses
                res_courses = await conn.execute(text("SELECT id FROM courses WHERE join_code IS NULL"))
                import secrets
                for row in res_courses.fetchall():
                    code = secrets.token_hex(3).upper()
                    await conn.execute(
                        text("UPDATE courses SET join_code = :code WHERE id = :id"),
                        {"code": code, "id": row[0]}
                    )
                
                # Add unique constraint after populating
                await conn.execute(text("ALTER TABLE courses ADD CONSTRAINT uq_course_join_code UNIQUE (join_code)"))
        except Exception as e:
            print(f"[STARTUP WARN] Auto-migration for join_code failed: {e}")

        # Auto-migration for is_approved column
        try:
            from sqlalchemy import text
            res = await conn.execute(
                text("SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name='is_approved'")
            )
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE users ADD COLUMN is_approved BOOLEAN DEFAULT TRUE"))
                await conn.execute(text("UPDATE users SET is_approved = TRUE WHERE is_approved IS NULL"))
        except Exception as e:
            print(f"[STARTUP WARN] Auto-migration for is_approved failed: {e}")

        # Auto-migration for token_valid_after column
        try:
            from sqlalchemy import text
            res = await conn.execute(
                text("SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name='token_valid_after'")
            )
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE users ADD COLUMN token_valid_after TIMESTAMP WITH TIME ZONE NULL"))
        except Exception as e:
            print(f"[STARTUP WARN] Auto-migration for token_valid_after failed: {e}")
            
    # Auto-seed admin account and migrate legacy accounts to professor role
    try:
        from app.db.base import async_session
        from app.models.user import User, UserRole
        from app.core.security import hash_password
        from sqlalchemy import select

        async with async_session() as session:
            # Seed admin if missing
            res_admin = await session.execute(
                select(User).where(User.email == "admin@professoros.edu.pk")
            )
            existing_admin = res_admin.scalar_one_or_none()
            if not existing_admin and get_settings().INITIAL_ADMIN_PASSWORD:
                admin_acc = User(
                    email="admin@professoros.edu.pk",
                    full_name="System Administrator",
                    hashed_password=hash_password(get_settings().INITIAL_ADMIN_PASSWORD),
                    role=UserRole.ADMIN,
                    is_active=True,
                    is_verified=True,
                    is_approved=True,
                )
                session.add(admin_acc)
            elif not existing_admin:
                print("[STARTUP WARN] Admin account is absent; set INITIAL_ADMIN_PASSWORD to bootstrap it securely.")

            # Update all existing accounts with role ADMIN (except system admin) to PROFESSOR
            res_legacy = await session.execute(
                select(User).where(
                    User.role == UserRole.ADMIN,
                    User.email != "admin@professoros.edu.pk"
                )
            )
            legacy_users = res_legacy.scalars().all()
            for u in legacy_users:
                u.role = UserRole.PROFESSOR
                u.is_approved = True
            
            await session.commit()
            print(f"[STARTUP] Successfully updated {len(legacy_users)} legacy admin accounts to professor role.")
    except Exception as e:
        print(f"[STARTUP WARN] Auto-seed/role update failed: {e}")
            
    yield
    await engine.dispose()


app = FastAPI(
    title="ProfessorOS API",
    description="Smart academic platform for Pakistani universities – Authentication, Course Management & Analytics.",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────
_settings = get_settings()
# ALLOWED_ORIGINS is validated to not be "*" in production
_origins = [o.strip() for o in _settings.ALLOWED_ORIGINS.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_origin_regex=r"^https://.*\.up\.railway\.app$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Register routers ─────────────────────────────────
from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.api.v1.courses import router as courses_router
from app.api.v1.assignments import router as assignments_router
from app.api.v1.analytics import router as analytics_router
from app.api.v1.submissions import router as submissions_router
from app.api.v1.exams import router as exams_router
from app.api.v1.quizzes import router as quizzes_router

app.include_router(auth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(assignments_router, prefix="/api/v1")
app.include_router(courses_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(submissions_router, prefix="/api/v1")
app.include_router(exams_router, prefix="/api/v1")
app.include_router(quizzes_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "ProfessorOS API"}


# ── Serve Flutter Web App ─────────────────────────────
if STATIC_DIR.exists():
    # Serve static assets (JS, CSS, icons, etc.)
    app.mount("/static_assets", StaticFiles(directory=str(STATIC_DIR)), name="static_assets")

    @app.get("/{full_path:path}")
    async def serve_flutter(full_path: str):
        """Serve Flutter web app for all non-API routes with cache-busting headers."""
        # Block directory traversal and dotfiles (.env, .git, etc.)
        if (
            ".." in full_path
            or full_path.startswith("/")
            or full_path.startswith("\\")
            or any(part.startswith(".") for part in full_path.split("/") if part)
        ):
            from fastapi import HTTPException
            raise HTTPException(status_code=403, detail="Access denied.")
        headers = {
            "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
            "Pragma": "no-cache",
            "Expires": "0",
        }
        resolved_static = STATIC_DIR.resolve()
        try:
            file_path = (STATIC_DIR / full_path).resolve()
            if not file_path.is_relative_to(resolved_static):
                from fastapi import HTTPException
                raise HTTPException(status_code=403, detail="Access denied.")
        except (ValueError, RuntimeError):
            from fastapi import HTTPException
            raise HTTPException(status_code=403, detail="Access denied.")

        if file_path.is_file():
            return FileResponse(str(file_path), headers=headers)

        # Do not return index.html for missing file/asset requests with an extension
        if file_path.suffix:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Resource not found.")

        # Fallback to index.html for Flutter router
        return FileResponse(str(STATIC_DIR / "index.html"), headers=headers)
else:
    @app.get("/")
    async def root():
        return {
            "service": "ProfessorOS API",
            "version": "1.0.0",
            "status": "running",
            "docs": "/docs",
            "health": "/health",
        }
