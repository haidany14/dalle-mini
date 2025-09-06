from __future__ import annotations

import ipaddress
import os
from typing import Optional
from urllib.parse import urlparse

import httpx
from fastapi import HTTPException


_client: Optional[httpx.AsyncClient] = None


def get_client() -> httpx.AsyncClient:
    """Get singleton HTTP client instance"""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=10.0,
            follow_redirects=False
        )
    return _client


async def invoke(method: str, url: str, **kwargs) -> httpx.Response:
    """Make HTTP request with SSRF protection"""
    # Parse URL
    try:
        parsed = urlparse(url)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid URL")
    
    # Check scheme
    if parsed.scheme not in ("http", "https"):
        raise HTTPException(status_code=400, detail="Only HTTP/HTTPS allowed")
    
    # Get allowed upstreams
    allowed_upstreams = os.getenv("ALLOWED_UPSTREAMS", "").split(",")
    allowed_upstreams = [upstream.strip() for upstream in allowed_upstreams if upstream.strip()]
    
    if not allowed_upstreams:
        raise HTTPException(status_code=503, detail="No upstream hosts configured")
    
    # Check if host is allowed
    if parsed.hostname not in allowed_upstreams:
        raise HTTPException(status_code=403, detail="Host not in allowlist")
    
    # Check for private IP ranges
    try:
        ip = ipaddress.ip_address(parsed.hostname)
        if ip.is_private or ip.is_loopback or ip.is_link_local:
            raise HTTPException(status_code=403, detail="Private IP ranges not allowed")
    except ValueError:
        # Not an IP address, hostname is okay
        pass
    
    # Make request
    client = get_client()
    try:
        response = await client.request(method, url, **kwargs)
        response.raise_for_status()
        return response
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=502,
            detail=f"Upstream error: {e.response.status_code}"
        )
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=502,
            detail=f"Upstream connection error"
        )
    except Exception:
        raise HTTPException(
            status_code=502,
            detail="Upstream request failed"
        )
