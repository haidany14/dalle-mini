#!/usr/bin/env bash
set -euo pipefail

# Kill any existing instance
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# Set environment
export API_KEY="dev-api-key"
export TELEGRAM_WEBHOOK_SECRET="dev-secret"
export ALLOWED_UPSTREAMS="api.github.com"
export UPLOAD_DIR="/workspace/uploads"

# Install prometheus-client if needed
pip3 install --break-system-packages -q prometheus-client 2>/dev/null || true

# Start app
echo "Starting Bot-Hub with metrics support..."
python3 -m uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 3

echo -e "\n=== Testing Updated Bot-Hub v1.0.3 ===\n"

# Test metrics endpoint
echo "1. Testing /metrics endpoint:"
curl -i http://localhost:8080/metrics 2>/dev/null | head -n 15
echo

# Test rate limit headers
echo -e "\n2. Testing rate limit headers on /health:"
curl -i http://localhost:8080/health 2>/dev/null | grep -i x-ratelimit || echo "No rate limit headers"
echo

# Test multiple requests to see rate limiting
echo -e "\n3. Testing rate limit behavior (5 rapid requests):"
for i in {1..5}; do
    echo -n "Request $i: "
    curl -s -o /dev/null -w "Status: %{http_code}, " http://localhost:8080/api/v1/status
    curl -s -I http://localhost:8080/api/v1/status 2>/dev/null | grep -i x-ratelimit-remaining || true
done

# Cleanup
echo -e "\n\nCleaning up..."
kill $APP_PID 2>/dev/null || true
echo "Done!"