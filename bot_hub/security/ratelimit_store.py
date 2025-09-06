from __future__ import annotations

import asyncio
import time
from typing import Optional

try:
    from redis import asyncio as aioredis  # type: ignore
except Exception:  # pragma: no cover
    aioredis = None  # type: ignore


class BaseRateLimitStore:
    async def incr(self, key: str, window_seconds: int) -> int:
        raise NotImplementedError

    async def ttl(self, key: str) -> int:
        raise NotImplementedError


class MemoryRateLimitStore(BaseRateLimitStore):
    def __init__(self) -> None:
        self._counters: dict[str, tuple[int, float]] = {}
        self._lock = asyncio.Lock()

    async def incr(self, key: str, window_seconds: int) -> int:
        async with self._lock:
            now = time.time()
            count, reset_at = self._counters.get(key, (0, now + window_seconds))
            if now > reset_at:
                count = 0
                reset_at = now + window_seconds
            count += 1
            self._counters[key] = (count, reset_at)
            return count

    async def ttl(self, key: str) -> int:
        async with self._lock:
            now = time.time()
            _, reset_at = self._counters.get(key, (0, now))
            ttl = int(max(0, reset_at - now))
            return ttl


class RedisRateLimitStore(BaseRateLimitStore):
    def __init__(self, url: str) -> None:
        if aioredis is None:
            raise RuntimeError("redis is not installed")
        self._client = aioredis.from_url(url, decode_responses=True)

    async def incr(self, key: str, window_seconds: int) -> int:
        pipe = self._client.pipeline()
        pipe.incr(key)
        pipe.expire(key, window_seconds)
        count, _ = await pipe.execute()
        return int(count)

    async def ttl(self, key: str) -> int:
        ttl = await self._client.ttl(key)
        return max(0, int(ttl))
