---
layout: default
title: Lab 4 — Custom Rules
parent: Labs
nav_order: 4
permalink: /labs/part4/
---

# Lab 4 — Custom Rules

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~30 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> IP block, rate-limit, geo-filter with Custom Rules</div>
  <div class="lab-meta__item">🔑 <strong>Concepts:</strong> Custom Rules, Priority, Rate Limiting, Geo-filter</div>
</div>

Create three Custom Rules — block `/admin` by IP address, rate-limit `/login` to prevent brute force, and geo-filter to allow only selected countries. Verify each rule with `curl`.

---

## How Custom Rules work

**Custom Rules** are WAF Policy rules you define yourself. They are evaluated **before** the managed DRS 2.1 ruleset, in ascending priority order (lowest number = first evaluated). If a Custom Rule matches and the action is `Block`, the request is stopped immediately — the DRS rules are never consulted.

Custom Rules support:

| Match condition | Examples |
|----------------|---------|
| `RequestUri` | Protect specific paths like `/admin`, `/login` |
| `RemoteAddr` | IP allowlists / blocklists |
| `RequestHeaders` | Match on User-Agent, Referer, etc. |
| `GeoMatch` | Country-of-origin filtering |

Custom Rule types:

- **MatchRule** — evaluates conditions once per request.
- **RateLimitRule** — counts requests over a time window per client IP; blocks when threshold is exceeded.

---

## Prerequisites

Set environment variables:

```bash
export WAF_POLICY_NAME=$(azd env get-values | grep WAF_POLICY_NAME | cut -d= -f2)
export RESOURCE_GROUP=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d= -f2)
export APPGW_URL=$(azd env get-values | grep APPGW_URL | cut -d= -f2)
export MY_IP=$(curl -s https://api.ipify.org)
```

---

## Section 1 — Block /admin by IP

Create a Custom Rule that blocks any request to `/admin` from an IP address that is **not** your own. This simulates protecting an admin interface from public internet access.

### Step 1 — Create the Custom Rule

```bash
az network application-gateway waf-policy custom-rule create \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name BlockAdminByIP \
  --priority 10 \
  --rule-type MatchRule \
  --action Block
```

### Step 2 — Add match condition: URI contains /admin AND source IP is not your IP

```bash
# Condition 1: request targets /admin
az network application-gateway waf-policy custom-rule match-condition add \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name BlockAdminByIP \
  --match-variable RequestUri \
  --operator Contains \
  --values "/admin"

# Condition 2: source IP is NOT your IP (negate the match)
az network application-gateway waf-policy custom-rule match-condition add \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name BlockAdminByIP \
  --match-variable RemoteAddr \
  --operator IPMatch \
  --negate true \
  --values "$MY_IP"
```

### Step 3 — Verify

```bash
# From your IP — should be allowed (200)
curl -v "$APPGW_URL/admin"

# From a different perspective (simulate with a non-matching IP in the condition):
# Use a VPN or change MY_IP to a different address to test blocking
curl -v "$APPGW_URL/admin" --header "X-Forwarded-For: 1.2.3.4"
# Expected: HTTP/1.1 403 Forbidden
```

---

## Section 2 — Rate-limit /login (brute force protection)

Create a Custom Rule that limits each client IP to 10 requests per minute on the `/login` endpoint.

### Step 1 — Create the rate limit rule

```bash
az network application-gateway waf-policy custom-rule create \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name RateLimitLogin \
  --priority 20 \
  --rule-type RateLimitRule \
  --action Block \
  --rate-limit-threshold 10 \
  --rate-limit-duration OneMin \
  --group-by-user-session '[{"groupByVariables":[{"variableName":"ClientAddr"}]}]'
```

### Step 2 — Add match condition: request targets /login

```bash
az network application-gateway waf-policy custom-rule match-condition add \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name RateLimitLogin \
  --match-variable RequestUri \
  --operator Contains \
  --values "/login"
```

### Step 3 — Verify (trigger the rate limit)

```bash
# Send 15 rapid requests to /login — the 11th+ should return 429
for i in $(seq 1 15); do
  echo -n "Request $i: "
  curl -s -o /dev/null -w "%{http_code}" "$APPGW_URL/login"
  echo
done
```

After 10 requests within one minute, subsequent requests will return **HTTP 429 Too Many Requests** until the window resets.

---

## Section 3 — Geo-filter (allow only selected countries)

Create a Custom Rule that blocks traffic originating outside of India (`IN`) and the United States (`US`). Adjust the country codes to match your expected user base.

### Step 1 — Create the geo-filter rule

```bash
az network application-gateway waf-policy custom-rule create \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name GeoFilter \
  --priority 30 \
  --rule-type MatchRule \
  --action Block
```

### Step 2 — Add match condition: GeoMatch NOT IN [IN, US]

```bash
az network application-gateway waf-policy custom-rule match-condition add \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --name GeoFilter \
  --match-variable RemoteAddr \
  --operator GeoMatch \
  --negate true \
  --values "IN" "US"
```

### Step 3 — Verify

Use a VPN exit node in a blocked country (e.g. Germany, DE) to confirm the 403 response, then disable the VPN and confirm your normal traffic passes.

---

## Section 4 — View Custom Rule matches in WAF logs

{: .tip }
> WAF firewall logs are stored in the **`AGWFirewallLogs`** resource-specific table. See the [AGWFirewallLogs schema reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/agwfirewalllogs) for all available columns.

```kusto
AGWFirewallLogs
| where Action == "Blocked"
| where isnotempty(UserDefinedRuleName)
| project TimeGenerated, ClientIp, RequestUri, UserDefinedRuleName, Action
| order by TimeGenerated desc
```

The `UserDefinedRuleName` column will show `BlockAdminByIP`, `RateLimitLogin`, or `GeoFilter` — confirming which Custom Rule fired.

{: .tip-title }
> ## Custom Rule priority order matters
>
> Custom Rules are evaluated in ascending priority order. Priority **10** (BlockAdminByIP) is evaluated before priority **20** (RateLimitLogin) and priority **30** (GeoFilter). If a request to `/admin` from a blocked IP matches BlockAdminByIP at priority 10, it is blocked immediately — the rate limit and geo rules never run.
>
> Reserve priorities 1–99 for Custom Rules, leaving headroom for future rules between existing ones.
