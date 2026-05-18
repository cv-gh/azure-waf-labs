#!/usr/bin/env bash
# Fix Script - Lab Part 3
# Switches WAF Policy to Prevention Mode and adds a Rule Exclusion
# to resolve the O'Brien False Positive.
# Usage: source <(azd env get-values) && ./scripts/fix-part3.sh

set -euo pipefail

if [ -z "${APPGW_URL:-}" ] || [ -z "${WAF_POLICY_NAME:-}" ] || [ -z "${AZURE_RESOURCE_GROUP:-}" ]; then
  echo "ERROR: Required env vars not set. Run: source <(azd env get-values)" >&2
  exit 1
fi

echo "=== Lab 3: Step 1 — Enable Prevention Mode ==="
az network application-gateway waf-policy update \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --set policySettings.mode=Prevention
echo "✓ WAF Policy switched to Prevention Mode"

echo ""
echo "=== Lab 3: Step 2 — Add Rule Exclusion for O'Brien FP ==="
echo "  Excluding rule 942100 on query parameter 'q' only"
az network application-gateway waf-policy managed-rule exclusion add \
  --policy-name "$WAF_POLICY_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --match-variable RequestArgNames \
  --selector q \
  --selector-match-operator Equals \
  --rule-set-type Microsoft_DefaultRuleSet \
  --rule-set-version 2.1 \
  --rule-group-name SQLI \
  --rules 942100
echo "✓ Rule Exclusion added (rule 942100 scoped to ?q= parameter)"

echo ""
echo "=== Done. Run verify-part3.sh to confirm FP resolved and TP preserved. ==="
