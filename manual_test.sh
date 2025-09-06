#!/usr/bin/env bash
# Manual smoke test - run each section separately

# === SETUP ===
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
python3 -m venv .venv && . .venv/bin/activate
pip install -r bot_hub/requirements.txt

# === ENVIRONMENT ===
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export CORS_ORIGINS=http://localhost:3000
export ALLOWED_UPSTREAMS=api.github.com

# === START APP (run in background) ===
uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
APP_PID=$!
sleep 2

# === TEST COMMANDS (run individually) ===

# Health check
curl -sS http://localhost:8080/health | jq .

# API status
curl -sS http://localhost:8080/api/v1/status | jq .

# Gateway invoke test
curl -sS -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | jq . | head -20

# File upload test (create test file first)
echo "Test file content" > test.txt
curl -sS -X POST http://localhost:8080/api/delivery/upload \
  -H "Authorization: Bearer $API_KEY" \
  -F "file=@test.txt" | jq .

# Telegram webhook test
curl -sS -X POST http://localhost:8080/api/telegram/webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: $TELEGRAM_WEBHOOK_SECRET" \
  -d '{
    "update_id": 1,
    "message": {
      "message_id": 1,
      "chat": {"id": 123},
      "text": "hello test"
    }
  }' | jq .

# === CLEANUP ===
kill $APP_PID