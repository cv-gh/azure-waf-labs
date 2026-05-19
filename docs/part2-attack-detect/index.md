---
layout: default
title: Lab 2 — Attack & Detect
parent: Labs
nav_order: 2
permalink: /labs/part2/
---

# Lab 2 — Attack & Detect

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~20 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> Fire attacks, observe True Positives in WAF logs</div>
  <div class="lab-meta__item">🔑 <strong>Concepts:</strong> True Positive, Detection Mode, KQL</div>
</div>

Fire SQLi, XSS, and path traversal attack payloads at the Vulnerable App while the WAF is in Detection Mode. Observe every hit as a **True Positive** in the Application Gateway WAF logs.

---

## Detection Mode behaviour

In Detection Mode the WAF inspects every request and writes a log entry for each rule match, but **passes the request through to the backend unchanged**. This means:

- Attacks return **HTTP 200** (the Vulnerable App responds normally).
- The WAF log shows the matched rule ID and payload.
- No traffic is blocked.

This is intentional for Lab 2 — you want to see *which* rules fire before you activate Prevention Mode in Lab 3.

---

## Understanding True Positives

A **True Positive (TP)** is a WAF rule match that correctly identifies a real attack. The WAF fired, and it was right to do so. In Detection Mode a TP shows up as `Action == "Detected"` in the WAF logs.

The opposite of a TP is a **False Positive (FP)** — a rule match that incorrectly flags legitimate traffic. You will encounter a deliberate FP in Lab 3.

---

## Step 1 — Set APPGW_URL

```bash
export APPGW_URL=$(azd env get-values | grep APPGW_URL | cut -d= -f2)
echo $APPGW_URL
```

---

## Step 2 — Fire a SQL Injection attack (rule 942100)

```bash
curl -v "$APPGW_URL/search?q=' OR 1=1--"
```

**What this does:** The payload `' OR 1=1--` is a classic SQL injection string. DRS 2.1 rule **942100** (SQL Injection Attack Detected via libinjection) matches the `q` query parameter.

**Expected response:** `HTTP/1.1 200 OK` — the Vulnerable App responds. Detection Mode does not block.

---

## Step 3 — Fire an XSS attack (rule 941100)

```bash
curl -v "$APPGW_URL/search?q=<script>alert(1)</script>"
```

**What this does:** The `<script>` tag is a canonical Cross-Site Scripting payload. DRS 2.1 rule **941100** (XSS Attack Detected via libinjection) matches.

**Expected response:** `HTTP/1.1 200 OK` — passed through, logged.

---

## Step 4 — Fire a path traversal attack (rule 930100)

```bash
curl -v "$APPGW_URL/file?name=../../etc/passwd"
```

**What this does:** The `../` sequence attempts to traverse out of the web root. DRS 2.1 rule **930100** (Path Traversal Attack) matches.

**Expected response:** `HTTP/1.1 200 OK` — passed through, logged.

---

## Step 5 — Run the full Attack Script

The repository includes a complete Attack Script that exercises multiple rule groups:

```bash
./scripts/attack-part2.sh
```

Review the script before running it to understand every payload and which DRS 2.1 rule group it targets.

---

## Step 6 — Query WAF logs in Log Analytics

Open the Log Analytics workspace in the portal, select **Logs**, and run:

{: .tip }
> WAF firewall logs are stored in the **`AGWFirewallLogs`** resource-specific table. See the [AGWFirewallLogs schema reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/agwfirewalllogs) for all available columns.

```kusto
AGWFirewallLogs
| where Action == "Detected"
| project TimeGenerated, ClientIp, RequestUri, RuleId, Message
| order by TimeGenerated desc
```

{: .success-title }
> ## True Positives confirmed
>
> You should see rows for rule IDs **942100**, **941100**, and **930100** (plus others from the Attack Script). Each row is a True Positive — the WAF correctly identified an attack payload.
>
> Key columns to review:
>
> | Column | Meaning |
> |--------|---------|
> | `RuleId` | DRS 2.1 rule that matched |
> | `RequestUri` | The URI + query string that triggered the rule |
> | `ClientIp` | Your IP address |
> | `Message` | Human-readable rule description |

{: .warning-title }
> ## Detection Mode means no blocking
>
> Every one of these requests reached your Vulnerable App. The `Action == "Detected"` value confirms the WAF *saw* the attack but did *not* stop it. This is the expected and correct behaviour for Detection Mode.
>
> In **Lab 3** you will switch to Prevention Mode — after which these same payloads will return **HTTP 403 Forbidden** before they reach the application.

---

## What about fixing the code?

The WAF caught every attack above — but the application code is still vulnerable. If the WAF were disabled, every one of these payloads would reach the database or browser and cause real damage.

In **Lab 3 Section 4** you will fix the underlying Flask app code:

| Vulnerability | Root cause | Code fix |
|---|---|---|
| SQLi in `/search` | f-string SQL: `f"... LIKE '%{query}%'"` | Parameterised query: `cursor.execute(sql, [f"%{query}%"])` |
| SQLi in `/login` | f-string SQL: `f"... username='{username}'"` | Parameterised query: `cursor.execute(sql, [username, password])` |
| Reflected XSS in `/search` | `{{ query \| safe }}` bypasses Jinja escaping | Remove `\| safe` → Jinja auto-encodes output |
| Path traversal in `/file` | No path sanitisation | `os.path.basename(name)` strips `../` sequences |

{: .tip }
> **WAF is defense-in-depth, not a substitute for secure code.** Fixing the code is always the primary fix. The WAF provides a second layer — it will still block attacks even after the code is hardened.

