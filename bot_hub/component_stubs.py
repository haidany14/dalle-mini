from __future__ import annotations

from fastapi import APIRouter, Path
from fastapi.responses import JSONResponse


gateway_router = APIRouter(prefix="/api/gateway")
deliver_router = APIRouter(prefix="/api/delivery")
telegram_router = APIRouter(prefix="/api/telegram")


@gateway_router.post("/route/{path:path}")
async def gateway_route(path: str = Path(...)):
    return JSONResponse(
        status_code=501,
        content={"detail": "Not implemented in this part"}
    )


@deliver_router.post("/upload")
async def delivery_upload():
    return JSONResponse(
        status_code=501,
        content={"detail": "Not implemented in this part"}
    )


@deliver_router.get("/status/{id}")
async def delivery_status(id: str):
    return JSONResponse(
        status_code=501,
        content={"detail": "Not implemented in this part"}
    )


@telegram_router.post("/webhook")
async def telegram_webhook():
    return JSONResponse(
        status_code=501,
        content={"detail": "Not implemented in this part"}
    )


@telegram_router.get("/status")
async def telegram_status():
    return JSONResponse(
        status_code=501,
        content={"detail": "Not implemented in this part"}
    )
