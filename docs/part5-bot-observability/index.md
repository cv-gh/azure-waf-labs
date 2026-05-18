---
layout: default
title: Lab 5 — Bot & Observability
parent: Labs
nav_order: 5
permalink: /labs/part5/
---

# Lab 5 — Bot Management & Observability

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~45 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> Bot Manager, KQL dashboards, alerting, Sentinel, teardown</div>
  <div class="lab-meta__item">🔑 <strong>Concepts:</strong> Bot Manager, Azure Monitor, Sentinel, KQL</div>
</div>

Enable the Bot Manager ruleset to classify and block known-bad bots, simulate bot traffic, build KQL queries for WAF observability, create an Azure Monitor alert on blocked requests, then tear down all resources with `azd down`.

---

## Section 1 — Enable the Bot Manager Ruleset

The **Microsoft_BotManagerRuleSet** is a separate managed ruleset from DRS 2.1. It classifies crawlers, scrapers, and known attack tools by User-Agent signature and other heuristics.

```bash
export WAF_POLICY_NAME=$(azd env get-values | grep WAF_POLICY_NAME | cut -d= -f2)
export RESOURCE_GROUP=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d= -f2)
export APPGW_URL=$(azd env get-values | grep APPGW_URL | cut -d= -f2)

az network application-gateway waf-policy managed-rule rule-set add \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --type Microsoft_BotManagerRuleSet \
  --version 1.0
```

Verify both rulesets are active:

```bash
az network application-gateway waf-policy show \
  --name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "managedRules.managedRuleSets[].{type:ruleSetType, version:ruleSetVersion}"
```

Expected output:

```json
[
  { "type": "Microsoft_DefaultRuleSet",  "version": "2.1" },
  { "type": "Microsoft_BotManagerRuleSet", "version": "1.0" }
]
```

---

## Section 2 — Simulate Bot Traffic

Send a request using the `sqlmap` User-Agent — a well-known SQL injection tool that Bot Manager identifies and blocks:

```bash
curl -v -H "User-Agent: sqlmap/1.7" "$APPGW_URL/api/products"
```

**Expected response:** `HTTP/1.1 403 Forbidden`

The Bot Manager ruleset matched the `sqlmap` User-Agent signature before DRS 2.1 even ran. Try a few more known bad user agents:

```bash
# Nikto web scanner
curl -v -H "User-Agent: Nikto/2.1.6" "$APPGW_URL/api/products"

# Masscan port scanner
curl -v -H "User-Agent: masscan/1.3" "$APPGW_URL/api/products"
```

Query the WAF logs to see Bot Manager detections:

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where ruleSetType_s == "BotProtection"
| project TimeGenerated, clientIp_s, requestUri_s, ruleId_s, message_s, action_s
| order by TimeGenerated desc
```

---

## Section 3 — KQL Queries for WAF Observability

Open the Log Analytics workspace and run these queries to build operational insight into your WAF.

### Blocked requests by rule ID (top 10)

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| summarize BlockCount = count() by ruleId_s
| top 10 by BlockCount desc
| render barchart
```

### Requests by client IP (top 20)

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| summarize RequestCount = count() by clientIp_s
| top 20 by RequestCount desc
```

### True Positive vs False Positive ratio over time

This query uses Prevention Mode action values to track the blocked-vs-detected ratio. After Tuning in Lab 3, you should see `Detected` volume drop significantly.

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| where action_s in ("Blocked", "Detected")
| summarize Count = count() by bin(TimeGenerated, 5m), action_s
| render timechart
```

### WAF log volume by hour

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| summarize Events = count() by bin(TimeGenerated, 1h)
| render columnchart
```

---

## Section 4 — Create an Azure Monitor Alert

Create an alert that fires when the number of WAF-blocked requests exceeds 10 in a 5-minute window. This gives your operations team early warning of an active attack or misconfiguration.

### Step 1 — Get the Log Analytics workspace resource ID

```bash
export LA_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name "log-$(azd env get-values | grep AZURE_ENV_NAME | cut -d= -f2)" \
  --query id -o tsv)
```

### Step 2 — Create the alert rule

```bash
az monitor scheduled-query create \
  --name "WAF-HighBlockRate" \
  --resource-group $RESOURCE_GROUP \
  --scopes $LA_WORKSPACE_ID \
  --condition-query "AzureDiagnostics | where ResourceType == 'APPLICATIONGATEWAYS' | where Category == 'ApplicationGatewayFirewallLog' | where action_s == 'Blocked' | summarize BlockCount = count()" \
  --condition "count BlockCount > 10" \
  --window-size "PT5M" \
  --evaluation-frequency "PT5M" \
  --severity 2 \
  --description "Alert when WAF blocks more than 10 requests in 5 minutes — possible active attack"
```

### Step 3 — Verify the alert in the portal

1. Open the resource group in the Azure portal.
2. Navigate to **Monitor → Alerts**.
3. Confirm `WAF-HighBlockRate` is listed and in an *Enabled* state.
4. Trigger the alert by running the Attack Script: `./scripts/attack-part2.sh`

---

## Section 5 — Send WAF Logs to Microsoft Sentinel

Microsoft Sentinel is a cloud-native SIEM that aggregates WAF logs alongside signals from across your Azure environment to detect coordinated attacks that span multiple services. The [WAF best practices](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/best-practices#send-logs-to-microsoft-sentinel) recommend forwarding WAF logs to Sentinel for production workloads.

{: .note-title }
> ## Sentinel requires a separate workspace
>
> Microsoft Sentinel is enabled on top of a Log Analytics workspace. For this lab you can enable it on the **existing** Log Analytics workspace deployed by `azd up` — no new workspace needed.

### Step 1 — Enable Microsoft Sentinel on the Log Analytics workspace

```bash
export LA_WORKSPACE_NAME="log-$(azd env get-values | grep AZURE_ENV_NAME | cut -d= -f2)"

az sentinel onboarding-state create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LA_WORKSPACE_NAME \
  --name default
```

### Step 2 — Enable the Azure WAF data connector

The Azure WAF connector imports `AzureDiagnostics` WAF log entries into Sentinel's unified security incident model.

```bash
az sentinel data-connector create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LA_WORKSPACE_NAME \
  --data-connector-id AzureWebApplicationFirewall \
  --name "AzureWAF" \
  --kind AzureWebApplicationFirewall
```

{: .tip }
> The WAF connector ingests the same `AzureDiagnostics` table you queried in Section 3 — no new data pipelines needed. Sentinel adds incident correlation, threat intelligence enrichment, and workbook dashboards on top.

### Step 3 — Verify ingestion in Sentinel

In the Azure portal:

1. Open **Microsoft Sentinel** → select your Log Analytics workspace.
2. Navigate to **Logs** and run:

```kusto
AzureDiagnostics
| where Category == "ApplicationGatewayFirewallLog"
| where action_s == "Blocked"
| project TimeGenerated, clientIp_s, ruleId_s, requestUri_s
| order by TimeGenerated desc
| take 20
```

You should see the same blocked requests from Labs 2–4 now surfaced inside Sentinel.

### Step 4 — (Optional) Enable the WAF Workbook

Sentinel includes a pre-built Azure WAF workbook with visualisations for blocked requests, top attack types, and geographic origin.

1. In Sentinel, go to **Workbooks → Templates**.
2. Search for **Azure Web Application Firewall (WAF)**.
3. Click **Save**, then **View saved workbook**.

{: .success-title }
> ## All MS WAF best practices covered
>
> With Sentinel connected, every recommendation from the [WAF best practices page](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/best-practices) is now demonstrated in this lab series:
>
> | Best Practice | Lab |
> |---|---|
> | Enable the WAF | Lab 1 |
> | Use WAF Policies | Lab 1 |
> | Use Detection Mode for tuning | Labs 1–2 |
> | Tune your WAF (Rule Exclusions) | Lab 3 |
> | Use Prevention Mode | Lab 3 |
> | Define WAF config as code (Bicep) | Lab 3 |
> | Enable core rule sets (DRS 2.1) | Lab 1 |
> | Enable bot management rules | Lab 5 |
> | Use latest ruleset versions (DRS 2.1) | Lab 1 |
> | Geo-filter traffic | Lab 4 |
> | Add diagnostic settings | Lab 1 |
> | Send logs to Microsoft Sentinel | Lab 5 ✓ |

---

## Section 6 — Clean Up

When you have finished all labs, delete all Azure resources to stop billing:

```bash
azd down
```

`azd down` removes the entire resource group, including the Application Gateway, App Service, SQL database, Log Analytics workspace, and all associated resources. This is the recommended cleanup path — do not delete resources individually.

{: .tip-title }
> ## Further reading
>
> To continue learning about Azure Application Gateway WAF:
>
> - [WAF best practices — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/best-practices)
> - [DRS 2.1 rule groups — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules)
> - [Bot Manager ruleset — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/bot-protection-overview)
> - [WAF Tuning guide — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-request-size-limits)
> - [WAF Policy as code with Bicep — Azure samples](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgatewaywebapplicationfirewallpolicies)
> - [Using Microsoft Sentinel with Azure WAF](https://learn.microsoft.com/en-us/azure/web-application-firewall/waf-sentinel)
