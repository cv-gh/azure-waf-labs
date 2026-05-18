#!/usr/bin/env bash
# Verify Script — Lab 3 Section 4
# Confirms code fixes work correctly:
#   ✓ O'Brien FP eliminated — returns 200 WITHOUT any Rule Exclusion
#   ✓ SQLi attacks still blocked by WAF — defense-in-depth preserved
#   ✓ Normal traffic unaffected
#
# Prerequisites:
#   - fix-code.sh has been applied and azd deploy completed
#   - The Rule Exclusion from Lab 3 Section 3 has been REMOVED
#
# Usage:
#   source <(azd env get-values) && ./scripts/verify-code-fix.sh

set -euo pipefail

if [ -z "${APPGW_URL:-}" ]; then
  echo "ERROR: APPGW_URL environment variable is not set." >&2
  echo "       Run: source <(azd env get-values)" >&2
  exit 1
fi

PASS=0
FAIL=0

check() {
  local label=$1 url=$2 expected=$3
  actual=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ PASS  [$actual] $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ FAIL  [got $actual, expected $expected] $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Lab 3 Section 4: Verifying Code Fix Results ==="
echo "    (Assumes Rule Exclusion from Section 3 is REMOVED)"
echo ""

echo "--- False Positive checks (200 via code fix — no Rule Exclusion needed) ---"
check "O'Brien search — FP eliminated by parameterised SQL" \
  "$APPGW_URL/search?q=O'Brien" "200"
check "O'Brien Life Vest search" \
  "$APPGW_URL/search?q=O'Brien Life Vest" "200"
check "Normal product search — Widget" \
  "$APPGW_URL/search?q=Widget" "200"

echo ""
echo "--- True Positive checks (WAF still blocks — defense-in-depth) ---"
check "SQLi OR 1=1 — still blocked by WAF" \
  "$APPGW_URL/search?q=' OR 1=1--" "403"
check "SQLi UNION SELECT — still blocked by WAF" \
  "$APPGW_URL/search?q=' UNION SELECT null--" "403"
check "XSS script tag — still blocked by WAF" \
  "$APPGW_URL/search?q=<script>alert(1)</script>" "403"
check "Path traversal — still blocked by WAF" \
  "$APPGW_URL/file?name=../../etc/passwd" "403"

echo ""
echo "--- Normal traffic (should be 200) ---"
check "Product API — unaffected"  "$APPGW_URL/api/products"  "200"
check "Login page — unaffected"   "$APPGW_URL/login"         "200"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "✓ Code fixes verified. O'Brien FP is eliminated at the application layer."
  echo "  WAF defense-in-depth is preserved — real attacks are still blocked."
  exit 0
else
  echo ""
  echo "Some checks failed. Ensure:"
  echo "  1. fix-code.sh was applied and azd deploy completed"
  echo "  2. The Rule Exclusion from Section 3 was removed"
  echo "  3. WAF Policy is still in Prevention Mode"
  exit 1
fi
