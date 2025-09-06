#!/usr/bin/env python3
"""Manual test to verify Bot-Hub functionality"""

import os
import time
import subprocess
import httpx

# Set environment
os.environ["API_KEY"] = "dev-api-key"
os.environ["TELEGRAM_WEBHOOK_SECRET"] = "dev-secret"
os.environ["ALLOWED_UPSTREAMS"] = "api.github.com,example.com"
os.environ["RATE_LIMIT_PER_MINUTE"] = "4"
os.environ["UPLOAD_DIR"] = "/workspace/uploads"

print("=== Bot-Hub Manual Test ===")
print(f"Environment: API_KEY={os.environ['API_KEY']}, RATE_LIMIT={os.environ['RATE_LIMIT_PER_MINUTE']}/min")
print()

# Start server
print("Starting server...")
proc = subprocess.Popen(
    ["python3", "-m", "uvicorn", "bot_hub.main:app", "--host", "127.0.0.1", "--port", "8080"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    env=os.environ.copy()
)

# Wait for server
time.sleep(3)
base = "http://127.0.0.1:8080"

try:
    # Test 1: Health
    print("1. Health check:", end=" ")
    r = httpx.get(f"{base}/health", timeout=5.0)
    print(f"✓ {r.status_code}" if r.status_code == 200 else f"✗ {r.status_code}")
    
    # Test 2: Status
    print("2. API Status:", end=" ")
    r = httpx.get(f"{base}/api/v1/status", timeout=5.0)
    print(f"✓ {r.status_code}, uptime={r.json().get('uptime', 0):.1f}s" if r.status_code == 200 else f"✗ {r.status_code}")
    
    # Test 3: Protected without auth
    print("3. Protected endpoint (no auth):", end=" ")
    r = httpx.post(f"{base}/api/gateway/invoke", json={"url": "https://api.github.com", "method": "GET"}, timeout=5.0)
    print(f"✓ {r.status_code} (expected 401/403)" if r.status_code in (401, 403) else f"✗ {r.status_code}")
    
    # Test 4: Telegram webhook
    print("4. Telegram webhook (no secret):", end=" ")
    r = httpx.post(f"{base}/api/telegram/webhook", json={"update_id": 1, "message": {"message_id": 1, "chat": {"id": 1}, "text": "hi"}}, timeout=5.0)
    print(f"✓ {r.status_code} (expected 401)" if r.status_code == 401 else f"✗ {r.status_code}")
    
    # Test 5: Telegram with secret
    print("5. Telegram webhook (with secret):", end=" ")
    r = httpx.post(
        f"{base}/api/telegram/webhook",
        headers={"X-Telegram-Bot-Api-Secret-Token": "dev-secret"},
        json={"update_id": 1, "message": {"message_id": 1, "chat": {"id": 1}, "text": "hi"}},
        timeout=5.0
    )
    print(f"✓ {r.status_code}" if r.status_code == 200 else f"✗ {r.status_code}")
    
    # Test 6: Rate limiting
    print("6. Rate limiting test (5 rapid requests):")
    saw_429 = False
    for i in range(5):
        r = httpx.get(f"{base}/api/v1/status", timeout=5.0)
        print(f"   Request {i+1}: {r.status_code}", end="")
        if r.status_code == 429:
            saw_429 = True
            print(" ← Rate limited!")
            break
        else:
            print(f" (remaining: {r.headers.get('x-ratelimit-remaining', '?')})")
    
    if saw_429:
        print("   ✓ Rate limiting works!")
    else:
        print("   ✗ No rate limit hit (may need lower limit)")
    
except Exception as e:
    print(f"\nError: {e}")
finally:
    # Cleanup
    proc.terminate()
    proc.wait()
    print("\nServer stopped.")