from __future__ import annotations

import os
from dataclasses import dataclass
from typing import List

import yaml


@dataclass
class RateLimitPolicy:
    per_minute: int
    burst: int


@dataclass
class GatewayPolicy:
    allow_methods: List[str]
    allow_headers: List[str]
    allow_origins: List[str]


@dataclass
class SecurityPolicy:
    rate_limit: RateLimitPolicy
    gateway: GatewayPolicy


def load_policy(path: str | None = None) -> SecurityPolicy:
    cfg_path = path or os.getenv("POLICY_FILE", os.path.join(os.path.dirname(__file__), "..", "config", "api_policies.yaml"))
    with open(cfg_path, "r", encoding="utf-8") as f:
        raw = yaml.safe_load(f)
    rl = raw.get("security", {}).get("rate_limit", {})
    gw = raw.get("gateway", {})
    return SecurityPolicy(
        rate_limit=RateLimitPolicy(
            per_minute=int(rl.get("per_minute", 60)),
            burst=int(rl.get("burst", 100)),
        ),
        gateway=GatewayPolicy(
            allow_methods=[str(m).upper() for m in gw.get("allow_methods", ["GET", "POST"])],
            allow_headers=[str(h) for h in gw.get("allow_headers", ["*"])],
            allow_origins=[str(o) for o in gw.get("allow_origins", ["*"])],
        ),
    )
