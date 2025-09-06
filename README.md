# Bot-Hub v1.0.3

# API Gateway and Bot Management Platform

# Features:
# - Secure API Gateway with SSRF protection
# - Rate limiting with Redis and in-memory fallback
# - Telegram bot integration
# - Streaming file uploads with validation
# - Health monitoring and observability

# Quick Start:
# 1. Copy .env.example to .env
# 2. Run: docker-compose -f docker-compose.bot.yml up
# 3. Access API at http://localhost:8080

# Endpoints:
# - GET /health - Health check
# - GET /ready - Readiness check
# - GET /metrics - Prometheus metrics
# - POST /api/gateway/route/{path} - Proxy requests
# - POST /api/delivery/upload - File upload
# - POST /api/telegram/webhook - Telegram webhook

# Smoke test (local, không Docker)
#   python -m venv .venv && . .venv/bin/activate
#   pip install -r bot_hub/requirements.txt
#   export API_KEY=dev-api-key
#   export TELEGRAM_WEBHOOK_SECRET=dev-secret
#   export ALLOWED_UPSTREAMS=api.github.com
#   uvicorn bot_hub.main:app --port 8080 &
#   curl -s http://localhost:8080/health
#   curl -s http://localhost:8080/api/v1/status
#   curl -s -X POST http://localhost:8080/api/gateway/invoke \n#     -H "Authorization: Bearer dev-api-key" -H "Content-Type: application/json" \n#     -d '{"url":"https://api.github.com","method":"GET"}'
#   curl -i http://localhost:8080/metrics | head -n 5
#   # Kiểm tra header rate limit:
#   curl -i http://localhost:8080/health | grep -i x-ratelimit

# License: MIT
