---
layout: default
title: Lab 6 — Fix the Code
parent: Labs
nav_order: 6
permalink: /labs/part6/
---

# Lab 6 — Fix the Code

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~20 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> Eliminate WAF False Positives by fixing the vulnerable application code</div>
  <div class="lab-meta__item">🧠 <strong>Concepts:</strong> Parameterised SQL, XSS escaping, path sanitisation, defense-in-depth</div>
</div>

---

## What you will do

In Labs 2 and 3 you saw the WAF block both **attacks** and **legitimate requests** (False Positives). In Lab 3 you added a Rule Exclusion as a WAF-layer workaround.

In this lab you fix the problem at the **source** — the vulnerable Flask application code. Once fixed:

- `O'Brien` search → **200 OK** (no Rule Exclusion needed)
- `' OR 1=1--` SQLi → **403 Forbidden** (WAF defense-in-depth still active)
- `<script>alert(1)</script>` XSS → **403 Forbidden** (WAF still active)

{: .note }
> **Why fix the code?** Rule Exclusions reduce WAF coverage. Every exclusion is a gap in your defense. The correct fix is always to remove the vulnerability from the application. The WAF then becomes a genuine second layer, not a first-and-only line.

---

## Prerequisites

- Lab 3 completed (WAF in Prevention Mode)
- `azd` CLI authenticated and `APPGW_URL` set: `source <(azd env get-values)`

---

## The three vulnerabilities

### Vulnerability 1 — SQL Injection in `/search`

**File:** `src/app/db.py` → `search_products()`

```python
# VULNERABLE: f-string interpolation
sql = f"SELECT id, name, price FROM products WHERE name LIKE '%{query}%'"
cursor.execute(sql)
```

When `query = "O'Brien"` the raw SQL becomes:

```sql
SELECT id, name, price FROM products WHERE name LIKE '%O'Brien%'
```

The unescaped apostrophe looks **identical** to a SQLi probe. The WAF fires rule **942100** and returns 403 — even though the request is completely legitimate.

**Fix — parameterised query:**

```python
# SECURE: value passed as a bound parameter, never concatenated into SQL
cursor.execute(
    "SELECT id, name, price FROM products WHERE name LIKE ?",
    [f"%{query}%"]
)
```

The SQLite driver escapes the apostrophe internally. The SQL string never contains a raw `'`. The WAF sees no SQLi signal.

---

### Vulnerability 2 — SQL Injection in `/login`

**File:** `src/app/db.py` → `check_login()`

```python
# VULNERABLE: f-string interpolation
sql = f"SELECT COUNT(*) FROM users WHERE username='{username}' AND password_hash='{password}'"
cursor.execute(sql)
```

A payload like `admin'--` in the username field terminates the SQL string and comments out the password check — classic authentication bypass.

**Fix — parameterised query:**

```python
# SECURE
cursor.execute(
    "SELECT COUNT(*) FROM users WHERE username=? AND password_hash=?",
    [username, password]
)
```

---

### Vulnerability 3 — Reflected XSS + Path Traversal in `app.py`

**File:** `src/app/app.py`

```jinja
{# VULNERABLE: | safe disables Jinja2 auto-escaping #}
<h1>Search Results for: {{ query | safe }}</h1>
```

A query like `<script>alert(document.cookie)</script>` renders as raw HTML in the browser. The WAF blocks rule **941100** in Prevention Mode — but if the WAF were bypassed the payload executes.

```python
# VULNERABLE: no path sanitisation on /file endpoint
name = request.args.get("name", "")
path = os.path.join(base_dir, name)   # ../../etc/passwd works
```

**Fix — remove `| safe` and sanitise path:**

```jinja
{# SECURE: Jinja2 auto-encodes < > & " ' #}
<h1>Search Results for: {{ query }}</h1>
```

```python
# SECURE: strip any ../ sequences
import os
name = os.path.basename(request.args.get("name", ""))
path = os.path.join(base_dir, name)
```

---

## Step 1 — Apply the code fixes

The secure versions are pre-built in the repo (`db_secure.py`, `app_secure.py`). The fix script swaps them in and redeploys:

```bash
source <(azd env get-values)
./scripts/fix-code.sh
```

What the script does:

| Action | Detail |
|---|---|
| Backup originals | `db.py.bak`, `app.py.bak` created |
| Apply `db_secure.py` | Parameterised SQL for `search_products` and `check_login` |
| Apply `app_secure.py` | `\| safe` removed, `os.path.basename()` added |
| Redeploy | `azd deploy` pushes the updated Flask app |

---

## Step 2 — Remove the Rule Exclusion (optional)

In Lab 3 you added a Rule Exclusion for parameter `q` on rule 942100. After this code fix, the exclusion is no longer needed — the `q` parameter no longer generates a SQLi signal.

```bash
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

{: .tip }
> If you skip this step, the exclusion has no effect (the code no longer triggers the rule). Removing it is best practice: tighten your WAF coverage when the underlying issue is resolved.

---

## Step 3 — Verify the fixes

```bash
./scripts/verify-code-fix.sh
```

Expected output:

```
=== Lab 6: Verifying Code Fix Results ===
    (Assumes Rule Exclusion from Lab 3 is REMOVED)

--- False Positive checks (200 via code fix — no Rule Exclusion needed) ---
  ✓ PASS  [200] O'Brien search — FP eliminated by parameterised SQL
  ✓ PASS  [200] O'Brien Life Vest search
  ✓ PASS  [200] Normal product search — Widget

--- True Positive checks (WAF still blocks — defense-in-depth) ---
  ✓ PASS  [403] SQLi OR 1=1 — still blocked by WAF
  ✓ PASS  [403] SQLi UNION SELECT — still blocked by WAF
  ✓ PASS  [403] XSS script tag — still blocked by WAF
  ✓ PASS  [403] Path traversal — still blocked by WAF

--- Normal traffic (should be 200) ---
  ✓ PASS  [200] Product API — unaffected
  ✓ PASS  [200] Login page — unaffected

=== Results: 9 passed, 0 failed ===

✓ Code fixes verified. O'Brien FP is eliminated at the application layer.
  WAF defense-in-depth is preserved — real attacks are still blocked.
```

{: .success-title }
> ## Lab 6 complete
>
> | Request | Before | After |
> |---|---|---|
> | `O'Brien` search | 403 FP ❌ | **200 OK** ✓ |
> | `' OR 1=1--` SQLi | 403 TP ✓ | **403 Forbidden** ✓ |
> | `<script>alert(1)</script>` XSS | 403 TP ✓ | **403 Forbidden** ✓ |
> | `../../etc/passwd` path traversal | 403 TP ✓ | **403 Forbidden** ✓ |
> | Normal `/search?q=Widget` | 200 ✓ | **200 OK** ✓ |
>
> The False Positive is eliminated at the application layer. The WAF stays in Prevention Mode and continues blocking real attacks — **defense-in-depth is preserved**.

---

## Rule Exclusion vs Code Fix — comparison

| | Rule Exclusion (Lab 3) | Code Fix (this lab) |
|---|---|---|
| **Where fix lives** | WAF Policy | Application source code |
| **FP eliminated?** | ✓ Yes | ✓ Yes |
| **WAF coverage reduced?** | ⚠️ Yes — `q` param excluded from rule 942100 | ✓ No — WAF fully active |
| **App still vulnerable?** | ⚠️ Yes — f-string SQL remains | ✓ No — parameterised queries |
| **Version-controlled?** | ✓ If Bicep is updated | ✓ Always (it's your code) |
| **Recommended?** | Temporary / legacy only | ✅ Always prefer this |

---

## Restore the vulnerable app

To go back to the intentionally vulnerable state for further testing:

```bash
git restore src/app/db.py src/app/app.py
azd deploy
```

Then re-add the Rule Exclusion from Lab 3 if needed.

---

{: .tip-title }
> ## Key takeaways
>
> - **WAF is defense-in-depth, not a substitute for secure code.** Fix the code first.
> - **False Positives are signals, not just noise.** An FP on `O'Brien` told you the app was using f-string SQL — a real vulnerability.
> - **Parameterised queries eliminate an entire class of SQLi** — both the WAF FP *and* the underlying attack vector.
> - **Remove Rule Exclusions when the code is fixed.** Every exclusion is a gap; close gaps when the root cause is gone.
