#!/usr/bin/env bash

# Set environment variables
export API_KEY="dev-api-key"
export TELEGRAM_WEBHOOK_SECRET="dev-secret"
export ALLOWED_UPSTREAMS="api.github.com"
export UPLOAD_DIR="/workspace/uploads"  # Use workspace dir instead of /app

# Create upload directory
mkdir -p /workspace/uploads

# Kill any existing instance
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# Start the app
echo "Starting Bot-Hub..."
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

echo -e "\n=== Bot-Hub Endpoint Tests ===\n"

# 1. Health
echo "# Health"
echo "curl -s http://localhost:8080/health"
curl -s http://localhost:8080/health
echo -e "\n"

# 2. Status
echo "# Status"
echo "curl -s http://localhost:8080/api/v1/status"
curl -s http://localhost:8080/api/v1/status
echo -e "\n"

# 3. Gateway invoke (with actual API_KEY)
echo "# Gateway invoke (requires API_KEY and allowlist)"
echo "curl -s -X POST http://localhost:8080/api/gateway/invoke \\"
echo "  -H \"Authorization: Bearer ${API_KEY}\" -H \"Content-Type: application/json\" \\"
echo "  -d '{\"url\":\"https://api.github.com\",\"method\":\"GET\"}'"
curl -s -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | python3 -m json.tool 2>/dev/null | head -15
echo -e "\n"

# 4. Upload (with actual API_KEY)
echo "# Upload (POST only; GET returns 405)"
echo "curl -s -X POST http://localhost:8080/api/delivery/upload \\"
echo "  -H \"Authorization: Bearer ${API_KEY}\" \\"
echo "  -F \"file=@README.md\""
curl -s -X POST http://localhost:8080/api/delivery/upload \
  -H "Authorization: Bearer ${API_KEY}" \
  -F "file=@README.md"
echo -e "\n"

# 5. Telegram webhook
echo "# Telegram webhook"
echo "curl -s -X POST http://localhost:8080/api/telegram/webhook \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-Telegram-Bot-Api-Secret-Token: ${TELEGRAM_WEBHOOK_SECRET}\" \\"
echo "  -d '{\"update_id\":1,\"message\":{\"message_id\":1,\"chat\":{\"id\":1},\"text\":\"hi\"}}'"
curl -s -X POST http://localhost:8080/api/telegram/webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: ${TELEGRAM_WEBHOOK_SECRET}" \
  -d '{"update_id":1,"message":{"message_id":1,"chat":{"id":1},"text":"hi"}}'
echo -e "\n"

# Cleanup
kill $APP_PID 2>/dev/null || true
echo -e "\n=== Tests complete ==="