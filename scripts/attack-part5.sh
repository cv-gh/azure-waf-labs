#!/usr/bin/env bash
# Attack Script - Lab Part 5
# Simulates bot traffic using known malicious User-Agent strings
# to test Bot Manager ruleset detection.
# Usage: APPGW_URL=https://<ip> ./scripts/attack-part5.sh

set -euo pipefail

if [ -z "${APPGW_URL:-}" ]; then
  echo "ERROR: APPGW_URL environment variable is not set." >&2
  echo "Usage: APPGW_URL=https://<your-appgw-ip> $0" >&2
  exit 1
fi

echo "=== Lab 5: Bot Management ==="
echo "Target: $APPGW_URL"
echo ""

echo "--- Bad bot: sqlmap (known attack tool) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "User-Agent: sqlmap/1.7.8#stable (https://sqlmap.org)" \
  "$APPGW_URL/api/products"

echo ""
echo "--- Bad bot: Nikto scanner ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "User-Agent: Mozilla/5.00 (Nikto/2.1.6)" \
  "$APPGW_URL/api/products"

echo ""
echo "--- Bad bot: custom scraper UA ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "User-Agent: python-requests/2.28.0" \
  "$APPGW_URL/api/products"

echo ""
echo "--- Good bot: Googlebot (should be allowed) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "User-Agent: Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
  "$APPGW_URL/api/products"

echo ""
echo "--- Normal browser UA (should be 200) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  "$APPGW_URL/api/products"

echo ""
echo "=== Done. Check WAF logs for bot classifications: ==="
echo "  AzureDiagnostics | where Category == 'ApplicationGatewayFirewallLog'"
echo "  | where ruleSetType_s == 'Microsoft_BotManagerRuleSet'"
