# Lab 1 — Deploy & Baseline

<div class="lab-meta">
  <div class="lab-meta__item">⏱ <strong>~30 min</strong></div>
  <div class="lab-meta__item">🎯 <strong>Goal:</strong> Deploy stack, verify connectivity, confirm Detection Mode</div>
  <div class="lab-meta__item">🔑 <strong>Concepts:</strong> azd, Detection Mode, Log Analytics</div>
</div>

Deploy the full infrastructure using `azd`, verify the Vulnerable App is reachable through the Application Gateway, confirm the WAF Policy is in Detection Mode, and locate the Log Analytics workspace where WAF logs will appear in later labs.

---

## Step 1 — Clone and deploy with azd

```bash
git clone https://github.com/cv-gh/azure-waf-labs
cd azure-waf-labs
azd up
```

`azd up` will:

1. Prompt you for an environment name (e.g. `waflab-dev`) and an Azure region.
2. Provision the resource group and all Bicep resources — Log Analytics workspace, Azure SQL, App Service, and Application Gateway with WAF Policy.
3. Deploy the Vulnerable App (Flask) to the App Service.

The deployment takes approximately **10–15 minutes**, most of which is the Application Gateway provisioning.

---

## Step 2 — Verify the Vulnerable App via App Gateway

Once `azd up` completes, grab the App Gateway public IP and confirm the Vulnerable App is serving traffic:

```bash
export APPGW_URL=$(azd env get-values | grep APPGW_URL | cut -d= -f2)
curl -s $APPGW_URL/api/products
```

You should receive a JSON array of products from the Azure SQL database. If you receive an error, check the App Service logs in the portal or run `azd monitor`.

---

## Step 3 — Confirm WAF is in Detection Mode

```bash
az network application-gateway waf-policy show \
  --name $(azd env get-values | grep WAF_POLICY_NAME | cut -d= -f2) \
  --resource-group $(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d= -f2) \
  --query "policySettings.mode"
```

Expected output:

```
"Detection"
```

!!! tip "Detection Mode vs Prevention Mode"
    In **Detection Mode**, the WAF inspects every request and writes a log entry for any rule that matches — but **never blocks** a request. All traffic passes through regardless of what rules fire.

    In **Prevention Mode** (enabled in Lab 3), a rule match causes the WAF to return **HTTP 403 Forbidden** and stop the request from reaching your application.

    Always start in Detection Mode so you can observe what the WAF would block *before* you commit to blocking it. This prevents unexpected False Positives from disrupting legitimate traffic.

---

## Step 4 — Navigate to Log Analytics

1. Open the [Azure portal](https://portal.azure.com) and navigate to the resource group created by `azd`.
2. Click the **Log Analytics workspace** (`log-<env-name>`).
3. In the left menu, select **Logs**.
4. In the query editor, run the following to confirm the WAF diagnostic connection is working:

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS"
| where Category == "ApplicationGatewayFirewallLog"
| take 10
```

The table may be empty at this stage — that is expected. WAF log entries will appear after you fire attack payloads in Lab 2.

---

!!! info "No attacks yet — establish your baseline"
    This lab establishes your baseline. The Vulnerable App is running, the WAF is in Detection Mode, and logs are flowing to Log Analytics. In **Lab 2** you will fire real attack payloads and observe them in these logs as True Positives.
