# Lab 5 — Bot Management & Observability

**Goal:** Enable the Bot Manager ruleset to classify and block known-bad bots, simulate bot traffic, build KQL queries for WAF observability, create an Azure Monitor alert on blocked requests, then tear down all resources with `azd down`.

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

## Section 5 — Clean Up

When you have finished all labs, delete all Azure resources to stop billing:

```bash
azd down
```

`azd down` removes the entire resource group, including the Application Gateway, App Service, SQL database, Log Analytics workspace, and all associated resources. This is the recommended cleanup path — do not delete resources individually.

!!! tip "Further reading"
    To continue learning about Azure Application Gateway WAF:

    - [WAF best practices — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/best-practices)
    - [DRS 2.1 rule groups — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules)
    - [Bot Manager ruleset — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/bot-protection-overview)
    - [WAF Tuning guide — Microsoft Learn](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-request-size-limits)
    - [WAF Policy as code with Bicep — Azure samples](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgatewaywebapplicationfirewallpolicies)
