---
layout: default
title: Lab 3 — Prevention & Tuning
parent: Labs
nav_order: 3
permalink: /labs/part3/
---

# Lab 3 — Prevention & Tuning

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~40 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> Enable Prevention Mode, resolve False Positive with Rule Exclusion</div>
  <div class="lab-meta__item">🔑 <strong>Concepts:</strong> Prevention Mode, False Positive, Rule Exclusion, Tuning</div>
</div>

Switch the WAF Policy to Prevention Mode, confirm attack payloads are now blocked (True Positives), deliberately trigger a False Positive with a legitimate search containing an apostrophe, then add a scoped Rule Exclusion to resolve it without disabling the SQLi rule.

{: .tip }
> Rule Exclusion Tuning is the core skill of WAF operations. This lab covers it end-to-end.

---

## Enabling Prevention Mode

### Step 1 — Switch WAF Policy to Prevention Mode

Set the environment variables from your azd environment:

```bash
export WAF_POLICY_NAME=$(azd env get-values | grep WAF_POLICY_NAME | cut -d= -f2)
export RESOURCE_GROUP=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d= -f2)
export APPGW_URL=$(azd env get-values | grep APPGW_URL | cut -d= -f2)
```

Apply the mode change:

```bash
az network application-gateway waf-policy update \
  --name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --set policySettings.mode=Prevention
```

### Step 2 — Confirm attack payloads are now blocked

Re-run the SQLi payload from Lab 2:

```bash
curl -v "$APPGW_URL/search?q=' OR 1=1--"
# Expected: HTTP/1.1 403 Forbidden
```

{: .success-title }
> ## True Positive
>
> The WAF correctly blocked the SQL injection attack. The Vulnerable App never saw the request. This is a **True Positive** — the WAF fired, and it was right.
>
> The response body will contain:
>
> ```
> <html><head><title>403 Forbidden</title></head>
> <body>The server is temporarily unable to service your request. Please try again later.</body>
> </html>
> ```

---

## Encountering a False Positive

### Step 3 — Search for "O'Brien" (a legitimate product name)

```bash
curl -v "$APPGW_URL/search?q=O'Brien"
# Expected: HTTP/1.1 403 Forbidden — but this is a LEGITIMATE search!
```

{: .warning-title }
> ## False Positive
>
> Rule **942100** matched the apostrophe in `O'Brien` as a SQL injection character. This is a **False Positive** — a legitimate request that was incorrectly blocked by the WAF.
>
> Your application sells products with apostrophes in their names (e.g. "O'Brien Wakeboard"). Without Tuning, every customer searching for this product gets a 403 error. The WAF has introduced a regression in application functionality.
>
> **The wrong fix** is to disable rule 942100 entirely — that would leave you exposed to real SQLi attacks.
>
> **The right fix** is a scoped Rule Exclusion.

### Step 4 — Confirm rule 942100 fired for the FP

```kusto
AzureDiagnostics
| where ruleId_s == "942100"
| project TimeGenerated, requestUri_s, details_message_s, action_s
```

Look for rows where `action_s == "Blocked"` and `requestUri_s` contains `O%27Brien` (URL-encoded apostrophe). This confirms rule 942100 is responsible.

---

## Tuning — Adding a Rule Exclusion

**Tuning** means adding a scoped **Rule Exclusion** to eliminate a False Positive without disabling the rule for all requests. The exclusion tells the WAF: "Don't apply rule 942100 when inspecting the `q` query parameter."

Everything else about rule 942100 remains active — it still inspects headers, cookies, request bodies, and all other query parameters.

### Step 5 — Add a Rule Exclusion scoped to query parameter `q` for rule 942100

```bash
az network application-gateway waf-policy managed-rule exclusion add \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --match-variable RequestArgNames \
  --selector q \
  --selector-match-operator Equals \
  --rule-set-type Microsoft_DefaultRuleSet \
  --rule-set-version 2.1 \
  --rule-group-name SQLI \
  --rules 942100
```

**What this exclusion does:**

| Setting | Value | Meaning |
|---------|-------|---------|
| `--match-variable` | `RequestArgNames` | Targets query string / POST body argument *names* |
| `--selector` | `q` | Only the argument literally named `q` |
| `--selector-match-operator` | `Equals` | Exact name match (not prefix/contains) |
| `--rule-group-name` | `SQLI` | Scoped to the SQL Injection rule group |
| `--rules` | `942100` | Only this specific rule |

The exclusion is intentionally narrow. It does not disable SQLi inspection on `/login`, `username`, `id`, or any other parameter.

### Step 6 — Verify the False Positive is resolved

```bash
curl -v "$APPGW_URL/search?q=O'Brien"
# Expected: HTTP/1.1 200 OK — legitimate search works again
```

### Step 7 — Verify the True Positive is still blocked

```bash
curl -v "$APPGW_URL/search?q=' OR 1=1--"
# Expected: HTTP/1.1 403 Forbidden — attack still blocked
```

{: .success-title }
> ## Tuning complete
>
> - `O'Brien` → **200 OK** — False Positive eliminated ✓
> - `' OR 1=1--` → **403 Forbidden** — True Positive preserved ✓
>
> Rule 942100 is still active for all other parameters and locations. You have resolved the FP with surgical precision.

{: .tip-title }
> ## WAF as Code
>
> In production, define Rule Exclusions in your Bicep modules so they are version-controlled, code-reviewed, and survive DRS ruleset upgrades. See **ADR-0001** in `docs/adr/` for the rationale for using DRS 2.1 instead of OWASP CRS 3.2, and the Bicep `appgateway.bicep` module for where to add `exclusions` to the `managedRules` block.
>
> Example Bicep exclusion:
>
> ```bicep
> exclusions: [
>   {
>     matchVariable: 'RequestArgNames'
>     selector: 'q'
>     selectorMatchOperator: 'Equals'
>     exclusionManagedRuleSets: [
>       {
>         ruleSetType: 'Microsoft_DefaultRuleSet'
>         ruleSetVersion: '2.1'
>         ruleGroups: [
>           {
>             ruleGroupName: 'SQLI'
>             rules: [ { ruleId: '942100' } ]
>           }
>         ]
>       }
>     ]
>   }
> ]
> ```

---

## Section 4 — Fix the Underlying Code

Rule Exclusions are a *WAF-layer* fix: you tell the WAF to trust a specific parameter. The application code remains vulnerable. Any attacker who bypasses the WAF — through a misconfigured exclusion or a novel payload — can still exploit the application.

The *correct* primary fix is to remove the vulnerability from the code. The WAF then becomes a true second layer of defense, not a first-and-only line.

| Approach | Where the fix lives | After the fix |
|---|---|---|
| **Rule Exclusion** (Section 3) | WAF Policy | WAF trusts the `q` parameter; app code still runs f-string SQL |
| **Code Fix** (this section) | Application source code | App uses parameterised SQL; WAF fires on real attacks only |

> **Best practice:** Fix the code first. Then evaluate whether the Rule Exclusion is still needed.

---

### The three vulnerabilities and their fixes

#### Fix 1 — Parameterise SQL in `search_products`

The False Positive for `O'Brien` exists because the search query is interpolated directly into the SQL string.

**Before (`src/app/db.py` — intentionally vulnerable):**

```python
# f-string injects the query value directly into SQL
cursor.execute(f"SELECT * FROM products WHERE name LIKE '%{query}%'")
```

When `query = "O'Brien"` the SQL becomes:
```sql
SELECT * FROM products WHERE name LIKE '%O'Brien%'
```
The unescaped apostrophe breaks the SQL syntax — which is *exactly* what the WAF sees as a SQLi pattern.

**After (`src/app/db_secure.py`):**

```python
# Parameterised query — the driver escapes the value safely
cursor.execute("SELECT * FROM products WHERE name LIKE ?", [f"%{query}%"])
```

Now `O'Brien` is passed as a bound parameter. The driver escapes it. The SQL never contains a raw apostrophe. **The WAF rule does not fire because the HTTP request no longer looks like SQLi.**

#### Fix 2 — Parameterise SQL in `check_login`

Same pattern in the login endpoint:

**Before:**

```python
cursor.execute(f"SELECT * FROM users WHERE username='{username}' AND password='{password}'")
```

**After:**

```python
cursor.execute("SELECT * FROM users WHERE username=? AND password=?", [username, password])
```

#### Fix 3 — Remove `| safe` from SEARCH_TEMPLATE and sanitise `/file`

**Before (`src/app/app.py`):**

```jinja
{{ query | safe }}   {# Jinja bypasses auto-escaping — XSS possible #}
```

```python
# /file endpoint — no path sanitisation
name = request.args.get("name", "")
with open(f"files/{name}", "r") as f:   # path traversal possible
```

**After (`src/app/app_secure.py`):**

```jinja
{{ query }}   {# Jinja auto-encodes <script> → &lt;script&gt; — XSS eliminated #}
```

```python
import os
name = os.path.basename(request.args.get("name", ""))  # strips ../ sequences
```

---

### Apply the code fixes

```bash
# Verify environment variables are set
source <(azd env get-values)

# Apply all three fixes and redeploy
./scripts/fix-code.sh
```

The script:
1. Creates `.bak` backups of `db.py` and `app.py`
2. Copies `db_secure.py` → `db.py` and `app_secure.py` → `app.py`
3. Runs `azd deploy`

---

### Remove the Rule Exclusion (optional)

After the code fix, the `q` parameter no longer generates a SQLi signal. You can remove the Rule Exclusion from Section 3:

```bash
# Remove the rule exclusion
POLICY_ID=$(az network application-gateway show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name waf-lab-appgw \
  --query "firewallPolicy.id" -o tsv)

az network application-gateway waf-policy managed-rule exclusion remove \
  --policy-name "${POLICY_ID##*/}" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --match-variable RequestArgNames \
  --selector q \
  --selector-match-operator Equals
```

---

### Verify the code fix

```bash
# Run the full verify suite
./scripts/verify-code-fix.sh
```

Expected results:

```
✓ PASS  [200] O'Brien search — FP eliminated by parameterised SQL
✓ PASS  [200] O'Brien Life Vest search
✓ PASS  [200] Normal product search — Widget
✓ PASS  [403] SQLi OR 1=1 — still blocked by WAF
✓ PASS  [403] SQLi UNION SELECT — still blocked by WAF
✓ PASS  [403] XSS script tag — still blocked by WAF
✓ PASS  [403] Path traversal — still blocked by WAF
✓ PASS  [200] Product API — unaffected
✓ PASS  [200] Login page — unaffected

=== Results: 9 passed, 0 failed ===
```

{: .success-title }
> ## Code fix verified
>
> | Request | Before code fix | After code fix |
> |---|---|---|
> | `O'Brien` search | 403 (FP) | **200 OK** ✓ |
> | `' OR 1=1--` SQLi | 403 (TP) | **403 Forbidden** ✓ |
> | `<script>alert(1)</script>` | 403 (TP) | **403 Forbidden** ✓ |
> | `../etc/passwd` | 403 (TP) | **403 Forbidden** ✓ |
> | Normal `/search?q=Widget` | 200 | **200 OK** ✓ |
>
> The False Positive is eliminated at the application layer. The WAF is still in Prevention Mode and still blocks real attacks — defence-in-depth is preserved.

{: .tip-title }
> ## Should you keep or remove the Rule Exclusion?
>
> | Scenario | Recommendation |
> |---|---|
> | Code is fixed and deployed | Remove the exclusion — it is no longer needed |
> | Code fix is in progress (other envs) | Keep the exclusion as a temporary measure |
> | Legacy code that cannot be changed | Keep the exclusion, document the risk |
>
> In production, always prefer the code fix. Exclusions reduce WAF coverage — every exclusion is a small gap in your defence. Track all exclusions in your WAF Policy Bicep module and review them on each DRS ruleset upgrade.

{: .warning }
> **To restore the vulnerable app for further testing:**
>
> ```bash
> git restore src/app/db.py src/app/app.py && azd deploy
> ```
