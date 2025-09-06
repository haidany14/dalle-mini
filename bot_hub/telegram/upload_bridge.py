from __future__ import annotations

import hashlib
from typing import Dict, Any


def stub_register_document(document: Dict[str, Any]) -> str:
    """
    Create a stub delivery record id from Telegram document metadata.
    We do not have bytes here (webhook only), so we persist a synthetic id.
    """
    basis = (document.get("file_unique_id") or document.get("file_id") or "") + (document.get("file_name") or "")
    digest = hashlib.sha256(basis.encode("utf-8")).hexdigest()
    return digest
