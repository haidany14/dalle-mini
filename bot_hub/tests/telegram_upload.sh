#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-http://localhost:8080}"
SECRET="${TELEGRAM_WEBHOOK_SECRET:-dev-secret}"

read -r -d '' PAYLOAD <<'JSON'
{
  "update_id": 123456789,
  "message": {
    "message_id": 1,
    "date": 1700000000,
    "chat": {"id": 999, "type": "private"},
    "text": "hello from test script",
    "document": {
      "file_id": "ABCDEF:123",
      "file_unique_id": "UNIQ123",
      "file_name": "sample.txt",
      "mime_type": "text/plain",
      "file_size": 12
    }
  }
}
JSON

curl -sS -X POST "$HOST/api/telegram/webhook" \n  -H "Content-Type: application/json" \n  -H "X-Telegram-Bot-Api-Secret-Token: $SECRET" \n  --data "$PAYLOAD" | jq .
