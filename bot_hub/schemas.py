from __future__ import annotations

from typing import Optional

from pydantic import BaseModel


class StatusResponse(BaseModel):
    app: str
    version: str
    uptime: float


class ErrorResponse(BaseModel):
    detail: str
    code: Optional[str] = None


class UploadResponse(BaseModel):
    id: str
    size: int
    mime: Optional[str] = None


class RateLimitInfo(BaseModel):
    limit: int
    remaining: int
    reset: int


class TelegramUpdate(BaseModel):
    update_id: int
    message: Optional[dict] = None
    edited_message: Optional[dict] = None
