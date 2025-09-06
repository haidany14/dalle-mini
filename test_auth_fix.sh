#!/usr/bin/env bash
set -euo pipefail

# Set environment
export API_KEY="dev-api-key"
export TELEGRAM_WEBHOOK_SECRET="dev-secret"
export ALLOWED_UPSTREAMS="api.github.com"

# Start app
echo "Starting Bot-Hub..."
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

echo -e "\nTesting auth endpoints:"

# Test with auth header (should work)
echo -e "\n1. With valid auth:"
curl -sS -X POST http://localhost:8080/api/delivery/upload \
  -H "Authorization: Bearer dev-api-key" \
  -F "file=@quick_test.sh" | head -50

# Test without auth (should return 401)
echo -e "\n\n2. Without auth (should be 401):"
curl -sS -o /dev/null -w "Status: %{http_code}\n" \
  http://localhost:8080/api/delivery/upload

# Test gateway with auth
echo -e "\n3. Gateway with auth:"
curl -sS -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | head -c 100

echo -e "\n\nCleaning up..."
kill $APP_PID 2>/dev/null || true
echo "Done!"