from __future__ import annotations

import os
import time
from typing import Any, Dict

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.responses import JSONResponse

from ..schemas import TelegramUpdate
from ..auth_guards import api_key_guard, AuthInfo
from .telegram_parser import normalize_update
from .upload_bridge import stub_register_document


router = APIRouter(prefix="/api/telegram", tags=["telegram"])


def _require_webhook_secret(provided: str | None) -> None:
    secret = os.getenv("TELEGRAM_WEBHOOK_SECRET", "")
    if not secret:
        # If not configured, reject to avoid open webhook
        raise HTTPException(status_code=503, detail="Webhook secret not configured")
    if not provided or provided != secret:
        raise HTTPException(status_code=401, detail="Invalid webhook secret")


@router.post("/webhook")
async def webhook(
    update: TelegramUpdate,
    x_secret: str | None = Header(default=None, alias="X-Telegram-Bot-Api-Secret-Token"),
):
    _require_webhook_secret(x_secret)

    normalized = normalize_update(update.model_dump())
    result: Dict[str, Any] = {"ok": True, "received": True, "ts": int(time.time())}

    if normalized.get("text"):
        result["type"] = "text"
        result["preview"] = normalized["text"][:120]

    if normalized.get("document"):
        # Create a stub delivery record (metadata only, no bytes on webhook)
        doc = normalized["document"]
        stub_id = stub_register_document(doc)

        # Optionally store in DELIVERY_DB as metadata-only placeholder
        try:
            from ..deliver import DELIVERY_DB  # local import to avoid cycles at startup
            DELIVERY_DB[stub_id] = {
                "filename": doc.get("file_name") or "telegram.bin",
                "size": int(doc.get("file_size") or 0),
                "mime": doc.get("mime_type") or "application/octet-stream",
                "path": f"telegram://{doc.get('file_id')}",
                "ts": int(time.time()),
                "source": "telegram",
            }
        except Exception:
            pass

        result["type"] = "document"
        result["delivery_stub_id"] = stub_id

    return JSONResponse(status_code=200, content=result)


@router.get("/status")
async def status(_auth: AuthInfo = Depends(api_key_guard)):
    return {"ok": True}
