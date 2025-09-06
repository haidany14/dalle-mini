from __future__ import annotations

from typing import Optional, Dict, Any

from fastapi import APIRouter, Body, Depends, HTTPException, Path, Query
from fastapi.responses import JSONResponse, StreamingResponse

from .mesh_client import invoke
from .auth_guards import api_key_guard, ip_filter_guard, hmac_guard, AuthInfo


gateway_router = APIRouter(prefix="/api/gateway", tags=["gateway"])


@gateway_router.post("/invoke")
async def gateway_invoke(
    url: str = Body(..., embed=True),
    method: str = Body("GET", embed=True),
    headers: Optional[Dict[str, str]] = Body(None, embed=True),
    data: Optional[Any] = Body(None, embed=True),
    _auth: AuthInfo = Depends(api_key_guard),
    _ip: AuthInfo = Depends(ip_filter_guard),
):
    method = method.upper()
    if method not in {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"}:
        raise HTTPException(status_code=405, detail="Method not allowed")

    kwargs: Dict[str, Any] = {}
    if headers:
        kwargs["headers"] = headers
    if data is not None:
        kwargs["content"] = data if isinstance(data, (bytes, bytearray)) else str(data).encode("utf-8")

    resp = await invoke(method=method, url=url, **kwargs)

    def _iter():
        yield resp.content

    return StreamingResponse(
        _iter(),
        status_code=resp.status_code,
        media_type=resp.headers.get("content-type", "application/octet-stream"),
        headers={k: v for k, v in resp.headers.items() if k.lower().startswith("x-")}
    )


@gateway_router.post("/route/{path:path}")
async def gateway_route(
    path: str = Path(...),
    host: str = Query(..., description="Allowed upstream host, must be in allowlist"),
    scheme: str = Query("https"),
    _auth: AuthInfo = Depends(api_key_guard),
    _ip: AuthInfo = Depends(ip_filter_guard),
):
    if scheme not in {"http", "https"}:
        raise HTTPException(status_code=400, detail="Invalid scheme")
    target = f"{scheme}://{host}/{path.lstrip('/')}"
    resp = await invoke(method="GET", url=target)
    return JSONResponse(status_code=resp.status_code, content={"status": "ok", "upstream_status": resp.status_code})
