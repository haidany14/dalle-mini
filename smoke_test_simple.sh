#!/usr/bin/env bash
set -euo pipefail

# 0) go to repo root
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# 1) Install deps globally with --break-system-packages (for container environment)
echo "=== Installing dependencies ==="
pip3 install --break-system-packages -r bot_hub/requirements.txt

# 2) env tối thiểu cho smoke
export API_KEY="${API_KEY:-dev-api-key}"
export TELEGRAM_WEBHOOK_SECRET="${TELEGRAM_WEBHOOK_SECRET:-dev-secret}"
export CORS_ORIGINS="${CORS_ORIGINS:-http://localhost:3000}"
export ALLOWED_UPSTREAMS="${ALLOWED_UPSTREAMS:-api.github.com}"

# 3) chạy app ở tab này (để đó)
echo "=== Starting Bot-Hub application ==="
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

# 4) smoke: health + status
echo "== /health"
curl -sS http://localhost:8080/health || echo "FAILED"
echo -e "\n"

echo "== /api/v1/status"
curl -sS http://localhost:8080/api/v1/status || echo "FAILED"
echo -e "\n"

# 5) smoke: gateway invoke (cần ALLOWED_UPSTREAMS=api.github.com)
echo "== /api/gateway/invoke -> https://api.github.com"
curl -sS -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET","headers":{"Accept":"application/json"}}' | head -c 200 || echo "FAILED"
echo -e "\n"

# 6) smoke: upload (dùng README.md làm mẫu)
echo "== /api/delivery/upload"
# Create a test file if README.md doesn't exist
echo "Test content" > test_upload.txt
curl -sS -X POST http://localhost:8080/api/delivery/upload \
  -H "Authorization: Bearer $API_KEY" \
  -F "file=@test_upload.txt" || echo "FAILED"
echo -e "\n"

# 7) smoke: telegram webhook
echo "== /api/telegram/webhook"
curl -sS -X POST http://localhost:8080/api/telegram/webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: $TELEGRAM_WEBHOOK_SECRET" \
  -d '{"update_id":1,"message":{"message_id":1,"chat":{"id":123},"text":"hi","document":{"file_id":"A","file_unique_id":"U","file_name":"x.txt","mime_type":"text/plain","file_size":1}}}' || echo "FAILED"
echo -e "\n"

# 8) dọn
echo "=== Cleaning up ==="
kill $APP_PID >/dev/null 2>&1 || true
rm -f test_upload.txt
echo "Done!"