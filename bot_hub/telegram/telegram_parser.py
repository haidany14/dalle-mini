from __future__ import annotations

from typing import Any, Dict, Optional


def normalize_update(update: Dict[str, Any]) -> Dict[str, Any]:
    """Extract common fields from Telegram update."""
    msg = update.get("message") or update.get("edited_message") or {}
    chat = msg.get("chat") or {}
    doc = msg.get("document") or None
    text = msg.get("text") or ""

    return {
        "chat_id": chat.get("id"),
        "message_id": msg.get("message_id"),
        "text": text,
        "document": _normalize_document(doc) if doc else None,
    }


def _normalize_document(doc: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "file_id": doc.get("file_id"),
        "file_unique_id": doc.get("file_unique_id"),
        "file_name": doc.get("file_name"),
        "mime_type": doc.get("mime_type"),
        "file_size": doc.get("file_size"),
    }
