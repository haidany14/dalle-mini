from __future__ import annotations

import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

from .schemas import StatusResponse
from .security.middleware import setup_security

# Start time for uptime calculation
START_TIME = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print(f"Starting Bot-Hub on port {os.getenv('PORT', '8080')}")
    yield
    # Shutdown
    print("Shutting down Bot-Hub")


app = FastAPI(
    title="Bot-Hub",
    version="1.0.3",
    lifespan=lifespan
)

# CORS configuration
cors_origins = os.getenv("CORS_ORIGINS", "").split(",")
cors_origins = [origin.strip() for origin in cors_origins if origin.strip()]
if cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Attach security middleware (rate limiting w/ Redis or in-memory)
setup_security(app)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/ready")
async def ready():
    return {"ready": True}


@app.get("/api/v1/status")
async def status() -> StatusResponse:
    return StatusResponse(
        app="bot-hub",
        version="1.0.3",
        uptime=time.time() - START_TIME
    )


@app.get("/metrics")
async def metrics():
    """
    Expose Prometheus metrics. Includes default Python/process metrics.
    """
    try:
        from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
        data = generate_latest()
        return Response(content=data, media_type=CONTENT_TYPE_LATEST)
    except Exception:
        return JSONResponse(status_code=503, content={"detail": "metrics unavailable"})


# Import routers with fallback
try:
    from .api_gateway import gateway_router
except ImportError:
    from .component_stubs import gateway_router

try:
    from .deliver import deliver_router
except ImportError:
    from .component_stubs import deliver_router

try:
    from .telegram import telegram_router
except ImportError:
    from .component_stubs import telegram_router

# Include routers
app.include_router(gateway_router)
app.include_router(deliver_router)
app.include_router(telegram_router)


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "code": "internal_error"}
    )
