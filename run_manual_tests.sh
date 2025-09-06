#!/usr/bin/env bash
set -euo pipefail

echo "=== Bot-Hub Manual Test Commands ==="
echo

# Kill any existing processes
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# 2) Set environment variables
echo "Setting environment variables..."
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com

# 3) Start app in background
echo -e "\nStarting Bot-Hub..."
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

echo -e "\n=== Running Tests ===\n"

# 4) health + rate-limit header
echo "4) health + rate-limit header:"
echo "$ curl -i http://localhost:8080/health | grep -Ei 'HTTP/|x-ratelimit'"
curl -i http://localhost:8080/health 2>/dev/null | grep -Ei 'HTTP/|x-ratelimit' || echo "No rate limit on /health"
echo

# 5) status
echo -e "\n5) status:"
echo "$ curl -s http://localhost:8080/api/v1/status"
curl -s http://localhost:8080/api/v1/status
echo

# 6) gateway proxy
echo -e "\n\n6) gateway proxy (với allowlist):"
echo "$ curl -s -X POST http://localhost:8080/api/gateway/invoke \\"
echo "    -H \"Authorization: Bearer dev-api-key\" -H \"Content-Type: application/json\" \\"
echo "    -d '{\"url\":\"https://api.github.com\",\"method\":\"GET\"}' | head -n 5"
curl -s -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer dev-api-key" -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | head -n 5
echo

# 7) metrics (Prometheus)
echo -e "\n7) metrics (Prometheus):"
echo "$ curl -i http://localhost:8080/metrics | head -n 10"
curl -i http://localhost:8080/metrics 2>/dev/null | head -n 10
echo

# Additional test: rate limit on API endpoints
echo -e "\n8) Bonus - rate limit headers on API endpoint:"
echo "$ curl -i http://localhost:8080/api/v1/status | grep -i x-ratelimit"
curl -i http://localhost:8080/api/v1/status 2>/dev/null | grep -i x-ratelimit
echo

# Cleanup
echo -e "\nCleaning up..."
kill $APP_PID 2>/dev/null || true
echo "Done!"