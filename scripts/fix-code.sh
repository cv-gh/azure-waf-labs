#!/usr/bin/env bash
# Fix Script — Lab 3 Section 4
# Applies secure code fixes to the Flask app and redeploys to App Service.
#
# What it fixes:
#   1. db.py   — parameterised SQL in search_products and check_login
#   2. app.py  — removes Markup() XSS bypass (restores Jinja2 auto-escaping for query)
#   3. app.py  — adds os.path.basename() sanitisation to /file endpoint
#
# After this script, O'Brien search returns 200 without any WAF Rule Exclusion.
# The WAF stays enabled for defense-in-depth.
#
# Usage:
#   source <(azd env get-values) && ./scripts/fix-code.sh
#
# To restore the vulnerable version:
#   git restore src/app/db.py src/app/app.py && azd deploy

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$REPO_ROOT/src/app/db_secure.py" ]; then
  echo "ERROR: Run this script from the repository root, or ensure db_secure.py exists." >&2
  exit 1
fi

if [ -z "${APPGW_URL:-}" ] || [ -z "${AZURE_RESOURCE_GROUP:-}" ]; then
  echo "ERROR: Required env vars not set. Run: source <(azd env get-values)" >&2
  exit 1
fi

echo "=== Lab 3 Section 4: Apply Code Fixes ==="
echo ""

echo "--- Fix 1: Parameterise SQL in db.py (resolves O'Brien False Positive) ---"
cp "$REPO_ROOT/src/app/db.py" "$REPO_ROOT/src/app/db.py.bak"
cp "$REPO_ROOT/src/app/db_secure.py" "$REPO_ROOT/src/app/db.py"
echo "  Before: f\"SELECT ... WHERE name LIKE '%{query}%'\""
echo "  After:  cursor.execute(\"SELECT ... WHERE name LIKE ?\", [\"%query%\"])"
echo "✓ db.py updated — f-string SQL replaced with parameterised cursor.execute(sql, params)"

echo ""
echo "--- Fix 2: Remove | safe filter + sanitise /file in app.py (restores XSS escaping) ---"
cp "$REPO_ROOT/src/app/app.py" "$REPO_ROOT/src/app/app.py.bak"
cp "$REPO_ROOT/src/app/app_secure.py" "$REPO_ROOT/src/app/app.py"
echo "  Before: Markup(query) passed to render_template() — Jinja2 skips escaping → XSS"
echo "  After:  plain query string — Jinja2 HTML-encodes on render → XSS eliminated"
echo "✓ app.py updated — Markup() XSS bypass removed, path traversal sanitised"

echo ""
echo "=== Redeploying Flask app with code fixes ==="
cd "$REPO_ROOT"
azd deploy
echo "✓ Redeployment complete"

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Remove the Rule Exclusion from Lab 3 Section 3 (optional — see lab doc)"
echo "  2. Run ./scripts/verify-code-fix.sh to confirm the fixes work"
echo ""
echo "To restore the vulnerable app:  git restore src/app/db.py src/app/app.py && azd deploy"
