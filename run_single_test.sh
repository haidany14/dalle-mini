#!/usr/bin/env bash
set -euo pipefail

# Kill any existing instances
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# Set test environment
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com,example.com
export RATE_LIMIT_PER_MINUTE=60  # Normal rate limit for manual testing
export UPLOAD_DIR=/workspace/uploads

# Create upload dir
mkdir -p /workspace/uploads

echo "=== Manual Test of Bot-Hub Endpoints ==="
echo

# Start the server
echo "Starting server..."
python3 -m uvicorn bot_hub.main:app --host 127.0.0.1 --port 8080 --log-level warning &
APP_PID=$!
sleep 3

# Test endpoints manually
echo -e "\n1. Health check:"
curl -s http://127.0.0.1:8080/health

echo -e "\n\n2. Status:"
curl -s http://127.0.0.1:8080/api/v1/status | python3 -m json.tool

echo -e "\n3. Protected endpoint without auth (should be 403):"
curl -s -w "\nStatus: %{http_code}\n" http://127.0.0.1:8080/api/gateway/invoke \
  -X POST -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}'

echo -e "\n4. Protected endpoint with auth:"
curl -s http://127.0.0.1:8080/api/gateway/invoke \
  -X POST -H "Authorization: Bearer dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | head -c 200

echo -e "\n\n5. Telegram webhook without secret (should be 401):"
curl -s -w "\nStatus: %{http_code}\n" http://127.0.0.1:8080/api/telegram/webhook \
  -X POST -H "Content-Type: application/json" \
  -d '{"update_id":1,"message":{"message_id":1,"chat":{"id":1},"text":"hi"}}'

echo -e "\n6. Telegram webhook with secret:"
curl -s http://127.0.0.1:8080/api/telegram/webhook \
  -X POST -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: dev-secret" \
  -d '{"update_id":1,"message":{"message_id":1,"chat":{"id":1},"text":"hi"}}'

# Cleanup
echo -e "\n\nCleaning up..."
kill $APP_PID 2>/dev/null || true
echo "Done!"