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
# - POST /api/gateway/route/{path} - Proxy requests
# - POST /api/delivery/upload - File upload
# - POST /api/telegram/webhook - Telegram webhook

# License: MIT
