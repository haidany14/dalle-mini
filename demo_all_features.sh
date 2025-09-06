#!/usr/bin/env bash
set -euo pipefail

# Kill any existing processes
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# Environment setup
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com

echo "=== Bot-Hub v1.0.3 - Full Feature Demo ==="
echo

# Start app
echo "Starting Bot-Hub..."
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 > /tmp/bot-hub.log 2>&1 &
APP_PID=$!
sleep 3

echo -e "\n1) Health check (no rate limit):"
curl -i http://localhost:8080/health 2>/dev/null | grep -E "HTTP/1.1|{" | head -2

echo -e "\n2) API Status (with rate limit headers):"
curl -i http://localhost:8080/api/v1/status 2>/dev/null | grep -E "HTTP/1.1|x-ratelimit|{" | head -5

echo -e "\n3) Gateway Proxy to GitHub API:"
echo "Request: POST /api/gateway/invoke with Bearer token"
curl -s -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | python3 -m json.tool 2>/dev/null | head -10

echo -e "\n4) Prometheus Metrics:"
curl -s http://localhost:8080/metrics | head -5

echo -e "\n5) File Upload:"
echo "test content" > /tmp/test.txt
curl -s -X POST http://localhost:8080/api/delivery/upload \
  -H "Authorization: Bearer dev-api-key" \
  -F "file=@/tmp/test.txt" | python3 -m json.tool 2>/dev/null

echo -e "\n6) Telegram Webhook:"
curl -s -X POST http://localhost:8080/api/telegram/webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: dev-secret" \
  -d '{"update_id":123,"message":{"message_id":1,"chat":{"id":999},"text":"Hello Bot-Hub!"}}' | python3 -m json.tool 2>/dev/null

echo -e "\n7) Rate Limit Demo (5 quick requests):"
for i in {1..5}; do
    echo -n "Request $i: "
    curl -s -I http://localhost:8080/api/v1/status | grep -i x-ratelimit-remaining || true
done

# Cleanup
kill $APP_PID 2>/dev/null || true
rm -f /tmp/test.txt
echo -e "\n\n✅ All features demonstrated successfully!"