"""ProfessorOS – Redis cache service (5-minute TTL, fault-tolerant)."""

import json
import logging
from typing import Optional

import redis.asyncio as redis

from app.core.config import get_settings

logger = logging.getLogger(__name__)
_redis_client: Optional[redis.Redis] = None
CACHE_TTL = 300  # 5 minutes


async def get_redis() -> Optional[redis.Redis]:
    """Get or create the Redis client singleton."""
    global _redis_client
    if _redis_client is None:
        settings = get_settings()
        _redis_client = redis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_timeout=0.2,
            socket_connect_timeout=0.2,
        )
    return _redis_client


async def cache_get(key: str) -> Optional[dict]:
    """Get a cached value by key (returns None on cache miss or Redis failure)."""
    try:
        r = await get_redis()
        if r is None:
            return None
        data = await r.get(key)
        if data:
            return json.loads(data)
    except Exception as e:
        logger.warning(f"Redis cache_get error: {e}")
    return None


async def cache_set(key: str, value: dict, ttl: int = CACHE_TTL) -> None:
    """Set a cached value with TTL (silently fails if Redis unavailable)."""
    try:
        r = await get_redis()
        if r is not None:
            await r.set(key, json.dumps(value, default=str), ex=ttl)
    except Exception as e:
        logger.warning(f"Redis cache_set error: {e}")


# In-memory blacklist fallback for development or when Redis is temporarily unavailable
_token_blacklist_memory: set = set()


async def blacklist_token(jti: str, ttl_seconds: int = 3600) -> None:
    """Add a JWT jti to the blacklist for the duration of its remaining lifetime."""
    if not jti:
        return
    _token_blacklist_memory.add(jti)
    try:
        r = await get_redis()
        if r is not None:
            await r.set(f"blacklist:{jti}", "1", ex=ttl_seconds)
    except Exception as e:
        logger.warning(f"Redis blacklist_token error: {e}")


async def is_token_blacklisted(jti: str) -> bool:
    """Check if a JWT jti has been invalidated."""
    if not jti:
        return False
    if jti in _token_blacklist_memory:
        return True
    try:
        r = await get_redis()
        if r is not None:
            val = await r.get(f"blacklist:{jti}")
            return val is not None
    except Exception as e:
        logger.warning(f"Redis is_token_blacklisted error: {e}")
    return False

