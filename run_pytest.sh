#!/usr/bin/env bash
set -euo pipefail

echo "=== Running Bot-Hub Pytest Suite ==="
echo

# Kill any existing instances
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# Install dependencies if needed
echo "Checking dependencies..."
pip3 install --break-system-packages -q pytest httpx 2>/dev/null || true

# Set test environment
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com,example.com
export RATE_LIMIT_PER_MINUTE=4

echo "Environment configured:"
echo "  API_KEY=$API_KEY"
echo "  TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET"
echo "  ALLOWED_UPSTREAMS=$ALLOWED_UPSTREAMS"
echo "  RATE_LIMIT_PER_MINUTE=$RATE_LIMIT_PER_MINUTE"
echo

# Run pytest with quiet flag
echo "Running: pytest -q"
echo "================================"
python3 -m pytest -q

echo
echo "================================"
echo "Test run complete!"