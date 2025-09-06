#!/usr/bin/env bash
set -euo pipefail

# Set environment variables
export API_KEY="dev-api-key"
export TELEGRAM_WEBHOOK_SECRET="dev-secret"
export ALLOWED_UPSTREAMS="api.github.com"

# Start the app if not running
echo "Starting Bot-Hub..."
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

echo -e "\n=== Testing Bot-Hub Endpoints ===\n"

# Health
echo "1. Health Check:"
curl -s http://localhost:8080/health
echo -e "\n"

# Status
echo "2. API Status:"
curl -s http://localhost:8080/api/v1/status
echo -e "\n"

# Gateway invoke (with actual API_KEY)
echo "3. Gateway Invoke (proxy to api.github.com):"
curl -s -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | head -c 500
echo -e "\n"

# Upload (with actual API_KEY)
echo "4. File Upload:"
# Create a test file
echo "Test file content for upload" > test_upload.txt
curl -s -X POST http://localhost:8080/api/delivery/upload \
  -H "Authorization: Bearer ${API_KEY}" \
  -F "file=@test_upload.txt"
echo -e "\n"

# Telegram webhook (with actual TELEGRAM_WEBHOOK_SECRET)
echo "5. Telegram Webhook:"
curl -s -X POST http://localhost:8080/api/telegram/webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: ${TELEGRAM_WEBHOOK_SECRET}" \
  -d '{"update_id":1,"message":{"message_id":1,"chat":{"id":1},"text":"hi"}}'
echo -e "\n"

# Cleanup
echo -e "\n=== Cleaning up ==="
kill $APP_PID 2>/dev/null || true
rm -f test_upload.txt
echo "Done!"