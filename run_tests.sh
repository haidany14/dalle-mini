#!/usr/bin/env bash
set -euo pipefail

echo "=== Running Bot-Hub Tests ==="
echo

# Kill any existing instances
pkill -f "uvicorn bot_hub.main:app" 2>/dev/null || true
sleep 1

# Install test dependencies
echo "Installing test dependencies..."
pip3 install --break-system-packages -q pytest httpx 2>/dev/null || true

# Set environment variables for testing
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com,example.com
export RATE_LIMIT_PER_MINUTE=4  # Low limit to test rate limiting

echo -e "\nEnvironment configured:"
echo "  API_KEY=$API_KEY"
echo "  TELEGRAM_WEBHOOK_SECRET=$TELEGRAM_WEBHOOK_SECRET"
echo "  ALLOWED_UPSTREAMS=$ALLOWED_UPSTREAMS"
echo "  RATE_LIMIT_PER_MINUTE=$RATE_LIMIT_PER_MINUTE"

# Run tests
echo -e "\nRunning pytest..."
python3 -m pytest -v

echo -e "\n✅ Tests completed!"