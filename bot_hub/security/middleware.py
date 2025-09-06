from __future__ import annotations

import os
from typing import Callable

from fastapi import FastAPI, Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response, JSONResponse

from .ratelimit_store import MemoryRateLimitStore, RedisRateLimitStore, BaseRateLimitStore
from .policy import load_policy


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: FastAPI, store: BaseRateLimitStore, window_seconds: int, limit: int):
        super().__init__(app)
        self.store = store
        self.window_seconds = window_seconds
        self.limit = limit

    async def dispatch(self, request: Request, call_next: Callable):
        path = request.url.path
        if path.startswith("/health") or path.startswith("/ready"):
            return await call_next(request)

        client = request.client.host if request.client else "unknown"
        key = f"rl:{client}"
        count = await self.store.incr(key, self.window_seconds)
        ttl = await self.store.ttl(key)

        headers = {
            "X-RateLimit-Limit": str(self.limit),
            "X-RateLimit-Remaining": str(max(0, self.limit - count)),
            "X-RateLimit-Reset": str(ttl),
        }

        if count > self.limit:
            return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded"}, headers=headers)

        response: Response = await call_next(request)
        for k, v in headers.items():
            response.headers[k] = v
        return response


def setup_security(app: FastAPI) -> None:
    policy = load_policy()
    per_minute = int(os.getenv("RATE_LIMIT_PER_MINUTE", policy.rate_limit.per_minute))
    window_seconds = 60

    store: BaseRateLimitStore
    redis_url = os.getenv("REDIS_URL", "")
    if redis_url:
        try:
            store = RedisRateLimitStore(redis_url)
        except Exception:
            store = MemoryRateLimitStore()
    else:
        store = MemoryRateLimitStore()

    app.add_middleware(
        RateLimitMiddleware,
        store=store,
        window_seconds=window_seconds,
        limit=per_minute,
    )
