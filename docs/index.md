# Azure Application Gateway WAF Lab

This lab series teaches you how to deploy, operate, and tune an **Azure Application Gateway WAF** using the **Default Ruleset (DRS) 2.1**. Working with a purpose-built **Vulnerable App** (a Flask API backed by Azure SQL), you will progress through five labs that take you from a bare deployment all the way to production-grade WAF hardening — covering Detection Mode, Prevention Mode, True Positive verification, False Positive identification, Rule Exclusion Tuning, Custom Rules, bot management, and operational observability.

## Architecture

```
Internet
   │
   ▼
App Gateway  ◄──── WAF Policy (DRS 2.1)
   │                  Detection → Prevention Mode
   │                  Rule Exclusions  |  Custom Rules
   ▼
App Service  ◄──── System-Assigned Managed Identity
(Flask)
   │
   ▼
Azure SQL Database  ◄──── MSI-based auth (no connection strings)
(Free tier)
```

## Prerequisites

- An **Azure subscription** with permission to create resource groups and deploy resources
- **Azure CLI** (`az`) and **Azure Developer CLI** (`azd`) — [install guide](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- **Python 3.12+** (for local app development and test scripts)
- **bash** (Git Bash on Windows is sufficient)

!!! warning "Cost Estimate"
    The Application Gateway WAF_v2 SKU costs approximately **$0.36/hr** (fixed capacity unit) plus $0.008 per gateway hour. Run `azd down` at the end of every session to avoid unnecessary charges. The App Service B1 plan and Azure SQL Free tier add minimal cost.

## Lab Overview

| Lab | What you do | Key concept |
|-----|-------------|-------------|
| **Lab 1** — Deploy & Baseline | Deploy infrastructure with `azd up`, verify the Vulnerable App via App Gateway, confirm Detection Mode | Detection Mode, Log Analytics |
| **Lab 2** — Attack & Detect | Fire SQLi, XSS, and path traversal payloads; observe True Positives in WAF logs | True Positive (TP), WAF log KQL |
| **Lab 3** — Prevention & Tuning | Enable Prevention Mode, trigger a False Positive on `O'Brien`, add a Rule Exclusion | False Positive (FP), Rule Exclusion, Tuning |
| **Lab 4** — Custom Rules | Block `/admin` by IP, rate-limit `/login`, geo-filter by country | Custom Rule, priority, rate limiting |
| **Lab 5** — Bot & Observability | Enable Bot Manager ruleset, simulate bot traffic, create Azure Monitor alert | Bot management, alerting, KQL dashboards |
