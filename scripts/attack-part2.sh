#!/usr/bin/env bash
# Attack Script - Lab Part 2
# Fires SQLi, XSS, and path traversal payloads against the WAF in Detection Mode.
# Usage: APPGW_URL=https://<your-appgw-ip> ./scripts/attack-part2.sh

set -euo pipefail

if [ -z "${APPGW_URL:-}" ]; then
  echo "ERROR: APPGW_URL environment variable is not set." >&2
  echo "Usage: APPGW_URL=https://<your-appgw-ip> $0" >&2
  exit 1
fi

echo "=== Lab 2: Attack & Detect ==="
echo "Target: $APPGW_URL"
echo ""

echo "--- SQLi: classic OR-based injection ---"
curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/search?q=' OR 1=1--"
echo ""

echo "--- SQLi: UNION-based injection ---"
curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/search?q=' UNION SELECT null,null--"
echo ""

echo "--- XSS: script tag injection ---"
curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/search?q=<script>alert(1)</script>"
echo ""

echo "--- XSS: event handler injection ---"
curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/search?q=<img src=x onerror=alert(1)>"
echo ""

echo "--- Path traversal: read /etc/passwd ---"
curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/file?name=../../etc/passwd"
echo ""

echo "--- Path traversal: read Windows system file ---"
curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/file?name=..\..\windows\system32\drivers\etc\hosts"
echo ""

echo "=== Done. Check WAF logs in Log Analytics for detected requests. ==="
