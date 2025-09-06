#!/usr/bin/env bash
set -euo pipefail

echo "=== Bot-Hub Manual Test with Virtual Environment ==="
echo

# Kill any existing uvicorn processes
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# 1) Create venv and install deps
echo "1) Creating virtual environment and installing dependencies..."
python3 -m venv .venv && . .venv/bin/activate
pip install -r bot_hub/requirements.txt

# 2) Set environment variables
echo -e "\n2) Setting environment variables..."
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com
# Optional Redis: export REDIS_URL=redis://localhost:6379/0

echo "   API_KEY=$API_KEY"
echo "   TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET"
echo "   ALLOWED_UPSTREAMS=$ALLOWED_UPSTREAMS"

# 3) Run app
echo -e "\n3) Starting Bot-Hub application..."
uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

# 4) Health + rate-limit header
echo -e "\n4) Testing /health endpoint with rate-limit headers:"
curl -i http://localhost:8080/health | grep -Ei 'HTTP/|x-ratelimit'

# 5) Status
echo -e "\n\n5) Testing /api/v1/status endpoint:"
curl -s http://localhost:8080/api/v1/status | python3 -m json.tool

# 6) Gateway proxy
echo -e "\n6) Testing gateway proxy to api.github.com:"
curl -s -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer dev-api-key" -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | head -n 5

# 7) Metrics
echo -e "\n\n7) Testing /metrics endpoint (Prometheus format):"
curl -i http://localhost:8080/metrics | head -n 10

# Cleanup
echo -e "\n\nPress Enter to stop the application..."
read
kill $APP_PID 2>/dev/null || true
deactivate 2>/dev/null || true
echo "Done!"