from __future__ import annotations

import os
import time
import subprocess
from typing import Generator

import httpx
import pytest


@pytest.fixture(scope="session", autouse=True)
def server() -> Generator[str, None, None]:
    """
    Start uvicorn as a subprocess for the whole test session.
    Exposes base URL as fixture value.
    """
    env = os.environ.copy()
    env.setdefault("API_KEY", "dev-api-key")
    env.setdefault("TELEGRAM_WEBHOOK_SECRET", "dev-secret")
    env.setdefault("ALLOWED_UPSTREAMS", "api.github.com,example.com")
    env.setdefault("RATE_LIMIT_PER_MINUTE", "4")

    proc = subprocess.Popen(
        ["python3", "-m", "uvicorn", "bot_hub.main:app", "--host", "127.0.0.1", "--port", "8080", "--log-level", "warning"],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    base = "http://127.0.0.1:8080"
    # wait for /health to be up
    for _ in range(60):
        try:
            r = httpx.get(base + "/health", timeout=1.0)
            if r.status_code == 200:
                break
        except Exception:
            pass
        time.sleep(0.2)
    else:
        proc.terminate()
        raise RuntimeError("Server failed to start")

    try:
        yield base
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


def test_end_to_end(server: str):
    api_key = os.environ["API_KEY"]
    headers_auth = {"Authorization": f"Bearer {api_key}"}

    # 1) Health
    r = httpx.get(f"{server}/health", timeout=5.0)
    assert r.status_code == 200 and r.json().get("status") == "ok"

    # 2) Status
    r = httpx.get(f"{server}/api/v1/status", timeout=5.0)
    assert r.status_code == 200 and "uptime" in r.json()

    # 3) Protected (no token) -> 403 (from HTTPBearer) or 401
    r = httpx.post(f"{server}/api/gateway/invoke", json={"url": "https://api.github.com", "method": "GET"}, timeout=10.0)
    assert r.status_code in (401, 403)

    # 4) Gateway with token and allowlisted host -> 2xx
    r = httpx.post(
        f"{server}/api/gateway/invoke",
        headers=headers_auth,
        json={"url": "https://api.github.com", "method": "GET"},
        timeout=20.0,
    )
    assert 200 <= r.status_code < 400

    # 5) Telegram webhook secret: missing -> 401; correct -> 200
    payload = {"update_id": 1, "message": {"message_id": 1, "chat": {"id": 1}, "text": "hi"}}
    r = httpx.post(f"{server}/api/telegram/webhook", json=payload, timeout=5.0)
    assert r.status_code == 401
    r = httpx.post(
        f"{server}/api/telegram/webhook",
        headers={"X-Telegram-Bot-Api-Secret-Token": os.environ["TELEGRAM_WEBHOOK_SECRET"]},
        json=payload,
        timeout=5.0,
    )
    assert r.status_code == 200 and r.json().get("ok") is True

    # 6) Rate limit: hit status multiple times until we see 429
    saw_429 = False
    for _ in range(10):
        r = httpx.get(f"{server}/api/v1/status", timeout=5.0)
        if r.status_code == 429:
            saw_429 = True
            break
    assert saw_429, "Expected to see HTTP 429 due to rate limiting"
