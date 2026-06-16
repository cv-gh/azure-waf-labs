# Azure WAF Lab

Hands-on labs for learning Azure Application Gateway WAF by deploying a deliberately vulnerable Flask app behind a WAF, exercising real attack paths, observing detections and blocks, tuning False Positives, and then fixing the application code.

- Docs site: https://cv-gh.github.io/azure-waf-labs/
- Deployment model: `azd` + Bicep
- App stack: Flask on App Service
- Data store: Azure SQL with system-assigned managed identity
- WAF stack: Application Gateway WAF_v2 + WAF Policy + DRS 2.1

## What this lab deploys

```text
Internet
  -> Application Gateway (WAF_v2, WAF Policy, DRS 2.1)
  -> App Service (Flask vulnerable app)
  -> Azure SQL Database
  -> Log Analytics
  -> Microsoft Sentinel (enabled in Lab 5)
```

The repo is designed as a guided progression:

1. **Lab 1 — Deploy & Baseline**: deploy the stack and confirm Detection Mode
2. **Lab 2 — Attack & Detect**: fire SQLi, XSS, and path traversal payloads and inspect WAF logs
3. **Lab 3 — Prevention & Tuning**: switch to Prevention Mode and resolve the deliberate `O'Brien` False Positive with a Rule Exclusion
4. **Lab 4 — Custom Rules**: add IP block, rate limit, and geo-filter rules
5. **Lab 5 — Bot & Observability**: enable Bot Manager, build KQL queries, add alerting, and onboard Sentinel
6. **Lab 6 — Fix the Code**: replace the intentionally vulnerable app code with secure versions and verify defense-in-depth still works

## Repository layout

```text
.
├── azure.yaml                  # azd project definition
├── infra/                      # Bicep for App Gateway, WAF Policy, App Service, SQL, Log Analytics
├── src/app/                    # Flask app, secure variants, templates, Dockerfile
├── scripts/                    # Attack, fix, and verification scripts used by the labs
├── docs/part*/                 # Per-lab walkthroughs published to GitHub Pages
├── index.md                    # Docs home page
├── labs.md                     # Docs lab index
└── tests/                      # Pytest coverage for app behavior and script guardrails
```

## Prerequisites

You need:

- An Azure subscription where you can create a resource group
- Azure CLI (`az`)
- Azure Developer CLI (`azd`)
- Python 3.12+
- Ruby + Bundler if you want to build the Jekyll docs locally
- `bash`

Recommended before you start:

```bash
az login
azd auth login
```

## Quick start

Clone the repo and deploy everything:

```bash
git clone https://github.com/cv-gh/azure-waf-labs
cd azure-waf-labs
azd up
```

`azd up` provisions:

- Log Analytics workspace
- App Service plan + Linux App Service
- Azure SQL server + `waflab` database
- Application Gateway WAF_v2
- WAF Policy in **Detection** mode with **DRS 2.1**
- App deployment from `src/app`

Provisioning usually takes the longest on Application Gateway creation.

## Get the lab environment values

After `azd up`, load the generated environment values:

```bash
source <(azd env get-values)
```

The labs use these values frequently:

- `APPGW_URL`
- `WAF_POLICY_NAME`
- `AZURE_RESOURCE_GROUP`
- `AZURE_ENV_NAME`

If you prefer manual exports:

```bash
export APPGW_URL=$(azd env get-values | grep APPGW_URL | cut -d= -f2)
export WAF_POLICY_NAME=$(azd env get-values | grep WAF_POLICY_NAME | cut -d= -f2)
export RESOURCE_GROUP=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d= -f2)
```

## Verify the deployment

Confirm the app responds through Application Gateway:

```bash
curl -s "$APPGW_URL/api/products"
```

Confirm the WAF starts in Detection Mode:

```bash
az network application-gateway waf-policy show \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query "policySettings.mode"
```

Expected:

```text
"Detection"
```

## How to run the lab

Read and follow the published walkthroughs in order:

- `docs/part1-deploy-baseline/index.md`
- `docs/part2-attack-detect/index.md`
- `docs/part3-prevention-tuning/index.md`
- `docs/part4-custom-rules/index.md`
- `docs/part5-bot-observability/index.md`
- `docs/part6-fix-code/index.md`

Typical flow:

### Lab 1
- Run `azd up`
- Verify `APPGW_URL/api/products`
- Confirm WAF Detection Mode
- Open Log Analytics and locate `AGWFirewallLogs`

### Lab 2
- Fire attack traffic with raw `curl` requests or `./scripts/attack-part2.sh`
- Expect `200` responses in Detection Mode
- Query `AGWFirewallLogs` for `Action == "Detected"`

### Lab 3
- Move the WAF to Prevention Mode
- Trigger the `O'Brien` False Positive
- Add the Rule Exclusion manually or with `./scripts/fix-part3.sh`
- Validate with `./scripts/verify-part3.sh`

### Lab 4
- Add Custom Rules for `/admin`, `/login`, and geo filtering
- Exercise them with `./scripts/attack-part4.sh`

### Lab 5
- Add Bot Manager rules
- Exercise bot detections with `./scripts/attack-part5.sh`
- Build KQL dashboards, create the alert, and enable Sentinel
- Tear down at the end with `azd down`

### Lab 6
- Apply secure code with `./scripts/fix-code.sh`
- Remove the temporary Rule Exclusion if desired
- Verify behavior with `./scripts/verify-code-fix.sh`

## Included scripts

All scripts live under `scripts/`.

| Script | Purpose |
|---|---|
| `attack-part2.sh` | Sends SQLi, XSS, and path traversal payloads in Detection Mode |
| `fix-part3.sh` | Switches WAF to Prevention Mode and adds the `q` Rule Exclusion for rule `942100` |
| `verify-part3.sh` | Confirms the False Positive is resolved while real attacks still block |
| `attack-part4.sh` | Exercises the Custom Rules lab |
| `attack-part5.sh` | Exercises Bot Manager detections |
| `fix-code.sh` | Replaces `app.py` and `db.py` with the secure variants and runs `azd deploy` |
| `verify-code-fix.sh` | Verifies Lab 6 outcomes after the secure code is deployed |

Most scripts require:

```bash
source <(azd env get-values)
```

The attack scripts require `APPGW_URL` to be set.

## Infrastructure details

Key implementation choices:

- `infra/main.bicep` orchestrates the full deployment
- `infra/modules/appgateway.bicep` creates the public IP, WAF Policy, Application Gateway, and diagnostic settings
- `infra/modules/appservice.bicep` creates the Linux App Service and injects SQL settings
- `infra/modules/sql.bicep` creates Azure SQL, enables Azure AD-only auth, and grants the App Service identity access
- `infra/modules/loganalytics.bicep` creates the Log Analytics workspace used for WAF and app logs

Notable defaults:

- WAF Policy starts in `Detection`
- DRS version is `2.1`
- Bot Manager is added later in Lab 5
- Rule Exclusions and Custom Rules are intentionally added during the lab with Azure CLI rather than pre-baked into Bicep

## App behavior

The default app in `src/app/app.py` and `src/app/db.py` is intentionally vulnerable:

- SQL injection surface in search and login
- Reflected XSS surface in search
- Path traversal surface in `/file`

Secure drop-in replacements exist here:

- `src/app/app_secure.py`
- `src/app/db_secure.py`

Lab 6 swaps those secure files into place.

## Local development and validation

### Run tests

From the repo root:

```bash
python -m pip install -r src/app/requirements.txt
python -m pytest
```

### Build the docs locally

From the repo root:

```bash
bundle install
bundle exec jekyll build
bundle exec jekyll serve
```

The docs site is generated from:

- `index.md`
- `labs.md`
- `docs/part*/index.md`
- `_config.yml`

### Run the Flask app locally

The production app entrypoint is `src/app/wsgi.py`, which creates the app with `SqlDb()`. For a real local run against SQL you need the database-related environment variables from `src/app/db.py`, including:

- `AZURE_SQL_SERVER`
- `AZURE_SQL_DATABASE`
- `AZURE_SQL_PASSWORD` for SQL auth fallback, or `AZURE_SQL_USE_MSI=true` in Azure
- optional `AZURE_SQL_USER`

The App Service command line is:

```bash
gunicorn --bind=0.0.0.0:8000 --timeout=120 wsgi:app
```

## WAF logs and observability

The labs use the `AGWFirewallLogs` table in Log Analytics for WAF verification.

Common checks:

```kusto
AGWFirewallLogs
| take 10
```

```kusto
AGWFirewallLogs
| where Action in ("Detected", "Blocked")
| project TimeGenerated, ClientIp, RequestUri, RuleId, Message, Action
| order by TimeGenerated desc
```

## Cleanup

When you are done, destroy the environment:

```bash
azd down
```

This removes the full resource group and is the intended cleanup path.

## Troubleshooting

- **`APPGW_URL` is empty**: run `source <(azd env get-values)` again or inspect `azd env get-values`
- **Application Gateway takes a long time**: that is normal during `azd up`
- **`403 Forbidden` for attack payloads**: expected after Lab 3 when Prevention Mode is enabled
- **`O'Brien` returns `403` in Lab 3**: expected before adding the Rule Exclusion or before applying the Lab 6 code fix
- **Normal traffic blocked after tuning changes**: query `AGWFirewallLogs` and inspect `RuleId`, `UserDefinedRuleName`, and `DetailedMessage`
- **Need the vulnerable app back after Lab 6**: run `git restore src/app/db.py src/app/app.py && azd deploy`

## Related docs

- Docs home: `index.md`
- Lab index: `labs.md`
- Architecture and terminology: `CONTEXT.md`
- ADRs: `docs/adr/`
