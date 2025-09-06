#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== Installing minimal dependencies ==="
pip3 install --break-system-packages -q fastapi uvicorn httpx aiofiles redis pyyaml python-multipart

# Set environment
export API_KEY="${API_KEY:-dev-api-key}"
export TELEGRAM_WEBHOOK_SECRET="${TELEGRAM_WEBHOOK_SECRET:-dev-secret}"
export CORS_ORIGINS="${CORS_ORIGINS:-http://localhost:3000}"
export ALLOWED_UPSTREAMS="${ALLOWED_UPSTREAMS:-api.github.com}"

echo "=== Starting Bot-Hub ==="
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

echo -e "\n=== Running smoke tests ==="

echo -e "\n1. Health check:"
curl -sS http://localhost:8080/health || echo "FAILED"

echo -e "\n\n2. API status:"
curl -sS http://localhost:8080/api/v1/status || echo "FAILED"

echo -e "\n\n3. Gateway test (requires auth):"
curl -sS -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' 2>&1 | head -c 200 || echo "FAILED"

echo -e "\n\n4. Protected endpoint without auth (should return 401):"
curl -sS -o /dev/null -w "Status: %{http_code}\n" \
  http://localhost:8080/api/delivery/upload || echo "FAILED"

echo -e "\n5. Telegram webhook with secret:"
curl -sS -X POST http://localhost:8080/api/telegram/webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: $TELEGRAM_WEBHOOK_SECRET" \
  -d '{"update_id":1,"message":{"message_id":1,"chat":{"id":123},"text":"test"}}' || echo "FAILED"

echo -e "\n\n=== Cleanup ==="
kill $APP_PID 2>/dev/null || true
echo "Tests complete!"