from __future__ import annotations

from fastapi import APIRouter
from .webhook_handler import router as telegram_router

__all__ = ["telegram_router"]
