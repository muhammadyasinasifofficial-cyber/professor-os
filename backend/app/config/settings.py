"""ProfessorOS – Centralized application settings & environment variables.

All configuration defaults are defined here using Pydantic v2 BaseSettings.
Includes provider-agnostic LLM pipelines, FAISS, Celery queues, Judge0 sandbox,
and Docling document ingestion.
"""

from functools import lru_cache
from typing import List, Optional
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Production configuration schema with sensible local-development defaults."""

    # ── Application Environment ─────────────────────────────────────────
    APP_NAME: str = "ProfessorOS"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    BACKEND_URL: str = "http://localhost:8000"
    FRONTEND_URL: str = "http://localhost:8080"
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080,http://127.0.0.1:8080,https://professor-os-production-65b2.up.railway.app"

    # Set to a mounted Railway Volume path (for example /data) in production.
    # Local ./data remains the safe development default.
    STORAGE_ROOT: str = "./data"

    # ── Database (PostgreSQL with asyncpg) ───────────────────────────────
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os"
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30

    # ── Message Broker & Caching (Redis) ────────────────────────────────
    REDIS_URL: str = "redis://localhost:6379/0"

    # ── Authentication & Cryptography ───────────────────────────────────
    JWT_SECRET_KEY: str = "professor-os-super-secret-jwt-key-minimum-32-chars-for-security"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    MAX_LOGIN_ATTEMPTS: int = 5
    LOCKOUT_DURATION_MINUTES: int = 15

    # ── Outbound Email ──────────────────────────────────────────────────
    EMAIL_BACKEND: str = "smtp"  # "smtp", "resend", or "console"
    EMAIL_FROM: str = "noreply@professor-os.edu.pk"
    RESEND_API_KEY: str = ""
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""

    # ── Primary LLM Provider: Groq (LPU Acceleration) ───────────────────
    GROQ_API_KEY: str = ""
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"

    # ── Fallback LLM Provider: OpenRouter (Automatic Failover) ──────────
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"

    # ── Future Local Hardware Migration (Ollama / vLLM / Local Box) ─────
    # When local GPU box is connected, set LLM_BASE_URL (e.g. http://localhost:11434/v1).
    # Setting this overrides both Groq and OpenRouter across all pipelines.
    LLM_BASE_URL: Optional[str] = None
    LLM_API_KEY: str = "ollama"

    # ── Pipeline 1: AI Grading (Deep Reasoning / Accuracy Critical) ─────
    MODEL_GRADING_PRIMARY: str = "deepseek-r1-distill-llama-70b"
    MODEL_GRADING_FALLBACK: str = "deepseek/deepseek-r1-distill-llama-70b"
    GRADING_MODEL_DEV: Optional[str] = None  # e.g. "llama-3.1-8b-instant" to save quota in development

    # ── Pipeline 2: RAG / AI Teaching Assistant (High Speed + Grounded) ─
    MODEL_RAG_PRIMARY: str = "ibm-granite-3-1-8b-instruct"
    MODEL_RAG_FALLBACK: str = "ibm/granite-3-1-8b-instruct"

    # ── Pipeline 3: Question Generation (Pedagogical Quality & Structure)
    MODEL_QUESTION_GEN_PRIMARY: str = "llama-3.3-70b-versatile"
    MODEL_QUESTION_GEN_FALLBACK: str = "meta-llama/llama-3.3-70b-instruct"

    # ── Pipeline 4: Local Embeddings & Vector Storage ───────────────────
    EMBEDDING_MODEL_NAME: str = "all-MiniLM-L6-v2"
    FAISS_STORAGE_PATH: str = "./data/faiss_indexes"

    # ── Document Parsing (IBM Docling) ──────────────────────────────────
    DOCLING_CACHE_PATH: str = "./data/docling_cache"
    DOCLING_MAX_CHUNK_TOKENS: int = 512
    DOCLING_CHUNK_OVERLAP_TOKENS: int = 64

    # ── Celery Task Queues (6 Designated Queues) ────────────────────────
    QUEUE_GRADING_HIGH: str = "grading_high"         # MCQ auto-grade, quiz scoring
    QUEUE_GRADING_NORMAL: str = "grading_normal"     # Essay + code grading via LLM
    QUEUE_XAI: str = "xai_queue"                     # LIME + criterion ablation
    QUEUE_RAG: str = "rag_queue"                     # Docling ingestion -> FAISS indexing
    QUEUE_QUESTION_GEN: str = "question_gen_queue"   # AI question generation from slides
    QUEUE_REPORTING: str = "reporting_queue"         # CLO attainment calc, HEC dossiers

    # ── Judge0 Code Sandbox (Isolated Evaluation) ───────────────────────
    JUDGE0_URL: str = "http://localhost:2358"
    JUDGE0_API_KEY: str = ""
    JUDGE0_TIMEOUT_SECONDS: float = 5.0

    # ── Field Normalization & Validators ────────────────────────────────
    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def fix_database_url(cls, v: str) -> str:
        if not v:
            return "postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os"
        if v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql+asyncpg://", 1)
        if v.startswith("postgresql://") and "+asyncpg" not in v:
            return v.replace("postgresql://", "postgresql+asyncpg://", 1)
        return v

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def validate_jwt_secret(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters for security.")
        return v

    @property
    def cors_origins_list(self) -> List[str]:
        """Returns ALLOWED_ORIGINS as a parsed list."""
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache()
def get_settings() -> Settings:
    """Cached singleton instance of application settings."""
    return Settings()
