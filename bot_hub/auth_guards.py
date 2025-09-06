from __future__ import annotations

import hashlib
import hmac
import ipaddress
import os
from dataclasses import dataclass
from typing import Optional

from fastapi import HTTPException, Request, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials


security = HTTPBearer()


@dataclass
class AuthInfo:
    who: str
    method: str


async def api_key_guard(credentials: HTTPAuthorizationCredentials = Depends(security)) -> AuthInfo:
    """Verify API key from Authorization: Bearer <token>"""
    api_key = os.getenv("API_KEY", "")
    if not api_key:
        raise HTTPException(status_code=401, detail="API key not configured")
    
    if credentials.credentials != api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    return AuthInfo(who="api-key", method="bearer")


async def hmac_guard(request: Request) -> AuthInfo:
    """Verify HMAC SHA256 signature from X-Signature header"""
    secret = os.getenv("HMAC_SECRET", "")
    if not secret:
        raise HTTPException(status_code=401, detail="HMAC secret not configured")
    
    signature_header = request.headers.get("X-Signature", "")
    if not signature_header:
        raise HTTPException(status_code=401, detail="Missing signature header")
    
    body_bytes = await request.body()
    expected_sig = hmac.new(
        secret.encode(),
        body_bytes,
        hashlib.sha256
    ).hexdigest()
    
    if not hmac.compare_digest(signature_header, expected_sig):
        raise HTTPException(status_code=401, detail="Invalid signature")
    
    return AuthInfo(who="hmac", method="sha256")


async def ip_filter_guard(request: Request) -> AuthInfo:
    """Enforce IP filtering based on ALLOWED_IPS and BLOCKED_IPS"""
    client_ip = request.client.host if request.client else ""
    
    # Check blocked IPs first
    blocked_ips = os.getenv("BLOCKED_IPS", "").split(",")
    blocked_ips = [ip.strip() for ip in blocked_ips if ip.strip()]
    
    for blocked in blocked_ips:
        try:
            if "/" in blocked:
                # CIDR notation
                network = ipaddress.ip_network(blocked, strict=False)
                if ipaddress.ip_address(client_ip) in network:
                    raise HTTPException(status_code=403, detail="IP blocked")
            else:
                # Single IP
                if client_ip == blocked:
                    raise HTTPException(status_code=403, detail="IP blocked")
        except ValueError:
            # Skip invalid entries
            continue
    
    # Check allowed IPs
    allowed_ips = os.getenv("ALLOWED_IPS", "").split(",")
    allowed_ips = [ip.strip() for ip in allowed_ips if ip.strip()]
    
    if allowed_ips:
        allowed = False
        for allowed_ip in allowed_ips:
            try:
                if "/" in allowed_ip:
                    # CIDR notation
                    network = ipaddress.ip_network(allowed_ip, strict=False)
                    if ipaddress.ip_address(client_ip) in network:
                        allowed = True
                        break
                else:
                    # Single IP
                    if client_ip == allowed_ip:
                        allowed = True
                        break
            except ValueError:
                # Skip invalid entries
                continue
        
        if not allowed:
            raise HTTPException(status_code=403, detail="IP not allowed")
    
    return AuthInfo(who=client_ip, method="ip-filter")
