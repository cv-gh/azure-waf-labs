# Lab 3 — Prevention & Tuning

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~40 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> Enable Prevention Mode, resolve False Positive with Rule Exclusion</div>
  <div class="lab-meta__item">🔑 <strong>Concepts:</strong> Prevention Mode, False Positive, Rule Exclusion, Tuning</div>
</div>

Switch the WAF Policy to Prevention Mode, confirm attack payloads are now blocked (True Positives), deliberately trigger a False Positive with a legitimate search containing an apostrophe, then add a scoped Rule Exclusion to resolve it without disabling the SQLi rule.

!!! tip "Most important lab"
    Rule Exclusion Tuning is the core skill of WAF operations. This lab covers it end-to-end.

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

!!! success "True Positive"
    The WAF correctly blocked the SQL injection attack. The Vulnerable App never saw the request. This is a **True Positive** — the WAF fired, and it was right.

    The response body will contain:
    ```
    <html><head><title>403 Forbidden</title></head>
    <body>The server is temporarily unable to service your request. Please try again later.</body>
    </html>
    ```

---

## Encountering a False Positive

### Step 3 — Search for "O'Brien" (a legitimate product name)

```bash
curl -v "$APPGW_URL/search?q=O'Brien"
# Expected: HTTP/1.1 403 Forbidden — but this is a LEGITIMATE search!
```

!!! warning "False Positive"
    Rule **942100** matched the apostrophe in `O'Brien` as a SQL injection character. This is a **False Positive** — a legitimate request that was incorrectly blocked by the WAF.

    Your application sells products with apostrophes in their names (e.g. "O'Brien Wakeboard"). Without Tuning, every customer searching for this product gets a 403 error. The WAF has introduced a regression in application functionality.

    **The wrong fix** is to disable rule 942100 entirely — that would leave you exposed to real SQLi attacks.

    **The right fix** is a scoped Rule Exclusion.

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

!!! success "Tuning complete"
    - `O'Brien` → **200 OK** — False Positive eliminated ✓
    - `' OR 1=1--` → **403 Forbidden** — True Positive preserved ✓

    Rule 942100 is still active for all other parameters and locations. You have resolved the FP with surgical precision.

!!! tip "WAF as Code"
    In production, define Rule Exclusions in your Bicep modules so they are version-controlled, code-reviewed, and survive DRS ruleset upgrades. See **ADR-0001** in `docs/adr/` for the rationale for using DRS 2.1 instead of OWASP CRS 3.2, and the Bicep `appgateway.bicep` module for where to add `exclusions` to the `managedRules` block.

    Example Bicep exclusion:
    ```bicep
    exclusions: [
      {
        matchVariable: 'RequestArgNames'
        selector: 'q'
        selectorMatchOperator: 'Equals'
        exclusionManagedRuleSets: [
          {
            ruleSetType: 'Microsoft_DefaultRuleSet'
            ruleSetVersion: '2.1'
            ruleGroups: [
              {
                ruleGroupName: 'SQLI'
                rules: [ { ruleId: '942100' } ]
              }
            ]
          }
        ]
      }
    ]
    ```
