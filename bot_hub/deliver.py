from __future__ import annotations

import hashlib
import os
import time
from pathlib import Path
from typing import Dict, Any

import aiofiles
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from fastapi.responses import JSONResponse

from .auth_guards import api_key_guard, ip_filter_guard, AuthInfo
from .schemas import UploadResponse


deliver_router = APIRouter(prefix="/api/delivery", tags=["delivery"])

UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "/app/uploads")).resolve()
DELIVERY_DB: Dict[str, Dict[str, Any]] = {}


@deliver_router.post("/upload", response_model=UploadResponse)
async def upload_file(
    file: UploadFile = File(...),
    _auth: AuthInfo = Depends(api_key_guard),
    _ip: AuthInfo = Depends(ip_filter_guard),
):
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    raw_name = f"{int(time.time()*1000)}_{file.filename or 'upload.bin'}"
    safe_name = "".join(c for c in raw_name if c.isalnum() or c in ("_", "-", ".", " "))
    dest = UPLOAD_DIR / safe_name

    sha256 = hashlib.sha256()
    size = 0

    async with aiofiles.open(dest, "wb") as f:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            await f.write(chunk)
            sha256.update(chunk)
            size += len(chunk)

    file_id = sha256.hexdigest()
    DELIVERY_DB[file_id] = {
        "filename": safe_name,
        "size": size,
        "mime": file.content_type or "application/octet-stream",
        "path": str(dest),
        "ts": int(time.time()),
    }

    return UploadResponse(id=file_id, size=size, mime=file.content_type)


@deliver_router.get("/status/{id}")
async def upload_status(
    id: str,
    _auth: AuthInfo = Depends(api_key_guard),
    _ip: AuthInfo = Depends(ip_filter_guard),
):
    meta = DELIVERY_DB.get(id)
    if not meta:
        raise HTTPException(status_code=404, detail="Not found")
    return JSONResponse(meta)
