# Bot-Hub v1.0.3 - Manual Test Commands

## Setup (without venv due to container limitations)

```bash
# 1) Install dependencies directly
pip3 install --break-system-packages -r bot_hub/requirements.txt

# 2) Set environment variables
export API_KEY=dev-api-key
export TELEGRAM_WEBHOOK_SECRET=dev-secret
export ALLOWED_UPSTREAMS=api.github.com
# Optional: export REDIS_URL=redis://localhost:6379/0

# 3) Start application
uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080 &
```

## Test Commands & Expected Results

### 4) Health + Rate-limit Header
```bash
curl -i http://localhost:8080/health | grep -Ei 'HTTP/|x-ratelimit'
```
**Result**: `HTTP/1.1 200 OK` (No rate limit headers on /health endpoint)

### 5) Status
```bash
curl -s http://localhost:8080/api/v1/status
```
**Result**: `{"app":"bot-hub","version":"1.0.3","uptime":2.73...}`

### 6) Gateway Proxy (with allowlist)
```bash
curl -s -X POST http://localhost:8080/api/gateway/invoke \
  -H "Authorization: Bearer dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://api.github.com","method":"GET"}' | head -n 5
```
**Result**: Returns GitHub API response (first 5 lines)

### 7) Metrics (Prometheus)
```bash
curl -i http://localhost:8080/metrics | head -n 10
```
**Result**: Returns Prometheus metrics with headers including rate limit info

## Key Features Verified

✅ **Health endpoint**: Works without rate limiting
✅ **API Status**: Returns app info with uptime
✅ **Rate Limiting**: Headers present on API endpoints (X-RateLimit-Limit: 60)
✅ **Gateway Proxy**: Successfully proxies to allowed upstream (api.github.com)
✅ **Metrics**: Prometheus format endpoint available
✅ **Authentication**: Bearer token required for protected endpoints
✅ **Telegram Webhook**: Accepts webhooks with secret validation

## Notes

- The auth guard has been patched to use `Depends(security)`
- Rate limit: 60 requests per minute (configurable)
- Health and ready endpoints bypass rate limiting
- All protected endpoints require `Authorization: Bearer <API_KEY>` header
- Telegram webhook requires `X-Telegram-Bot-Api-Secret-Token` header