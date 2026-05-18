#!/usr/bin/env bash
# Verify Script - Lab Part 3
# Confirms: (1) O'Brien FP resolved → 200 OK
#           (2) SQLi TP still blocked → 403 Forbidden
# Usage: APPGW_URL=https://<ip> ./scripts/verify-part3.sh

set -euo pipefail

if [ -z "${APPGW_URL:-}" ]; then
  echo "ERROR: APPGW_URL environment variable is not set." >&2
  exit 1
fi

PASS=0
FAIL=0

check() {
  local label=$1 url=$2 expected=$3
  actual=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [ "$actual" = "$expected" ]; then
    echo "✓ PASS  [$actual] $label"
    PASS=$((PASS + 1))
  else
    echo "✗ FAIL  [got $actual, expected $expected] $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Lab 3: Verifying Tuning Results ==="
echo ""

echo "--- False Positive check (should be 200 after Rule Exclusion) ---"
check "O'Brien search — FP resolved"       "$APPGW_URL/search?q=O'Brien"       "200"

echo ""
echo "--- True Positive checks (should still be 403 in Prevention Mode) ---"
check "SQLi OR 1=1 — TP preserved"        "$APPGW_URL/search?q=' OR 1=1--"    "403"
check "SQLi UNION SELECT — TP preserved"  "$APPGW_URL/search?q=' UNION SELECT null--" "403"
check "XSS script tag — TP preserved"     "$APPGW_URL/search?q=<script>alert(1)</script>" "403"
check "Path traversal — TP preserved"     "$APPGW_URL/file?name=../../etc/passwd" "403"

echo ""
echo "--- Normal traffic (should be 200) ---"
check "Product API — unaffected"          "$APPGW_URL/api/products"            "200"
check "Login page — unaffected"           "$APPGW_URL/login"                   "200"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
