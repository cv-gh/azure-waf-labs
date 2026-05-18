#!/usr/bin/env bash
# Attack Script - Lab Part 4
# Tests Custom Rules: IP block on /admin, rate limit on /login, geo-filter.
# Usage: APPGW_URL=https://<ip> ./scripts/attack-part4.sh

set -euo pipefail

if [ -z "${APPGW_URL:-}" ]; then
  echo "ERROR: APPGW_URL environment variable is not set." >&2
  echo "Usage: APPGW_URL=https://<your-appgw-ip> $0" >&2
  exit 1
fi

echo "=== Lab 4: Custom Rules ==="
echo "Target: $APPGW_URL"
echo ""

echo "--- Test 1: /admin access (should be 403 after IP block Custom Rule) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$APPGW_URL/admin"

echo ""
echo "--- Test 2: Rate limit on /login — send 15 POST requests rapidly ---"
echo "  (Custom Rule threshold: 10 req/min/IP — requests 11+ should be 429)"
for i in $(seq 1 15); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -d "username=admin&password=wrong" "$APPGW_URL/login")
  echo "  Request $i: HTTP $code"
done

echo ""
echo "--- Test 3: Normal traffic still flows ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$APPGW_URL/api/products"

echo ""
echo "=== Done. Check WAF logs for Custom Rule matches (ruleId_s contains 'BlockAdmin', 'RateLimitLogin'). ==="
