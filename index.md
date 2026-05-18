---
layout: default
title: Home
nav_order: 1
description: "Hands-on labs for Azure Application Gateway WAF"
permalink: /
---

<div class="hero">
<h1 class="hero-title">Azure Application Gateway WAF<br>Hands-On Lab</h1>
<p class="hero-sub">Deploy a vulnerable Flask app behind Azure WAF, fire real attacks, observe True Positives and False Positives, then harden step-by-step using DRS 2.1 best practices.</p>
<div class="hero-badges">

![Azure](https://img.shields.io/badge/Azure-App_Gateway-0078d4?style=flat-square&logo=microsoftazure&logoColor=white)
![WAF](https://img.shields.io/badge/WAF-DRS_2.1-ff5722?style=flat-square)
![azd](https://img.shields.io/badge/azd-ready-5c2d91?style=flat-square)
![Labs](https://img.shields.io/badge/Labs-6_parts-3f51b5?style=flat-square)

</div>
</div>

## Architecture

```
Internet
   │
   ▼
┌─────────────────────────────────────────────┐
│  Application Gateway  (WAF_v2)              │
│  WAF Policy · DRS 2.1 · Bot Manager         │
│  Rule Exclusions · Custom Rules             │
└─────────────────────────────────────────────┘
   │  Detection Mode → Prevention Mode
   ▼
┌──────────────────────────────┐
│  App Service  (Flask)        │
│  System-Assigned MSI         │
└──────────────────────────────┘
   │  Passwordless auth
   ▼
┌──────────────────────────────┐
│  Azure SQL Database          │
│  Free tier · AAD-only auth   │
└──────────────────────────────┘
        │
        ▼
   Log Analytics  →  Microsoft Sentinel
```

## Labs

<div class="lab-grid">
<a class="lab-card" href="{{ '/labs/part1/' | relative_url }}">
<div class="num">Lab 1</div>
<div class="title">Deploy &amp; Baseline</div>
<div class="desc">Deploy the full stack with <code>azd up</code>, verify the Vulnerable App, confirm Detection Mode, and locate WAF logs in Log Analytics.</div>
<div class="tags"><span class="tag">azd</span> <span class="tag">Detection Mode</span> <span class="tag">Log Analytics</span></div>
</a>

<a class="lab-card" href="{{ '/labs/part2/' | relative_url }}">
<div class="num">Lab 2</div>
<div class="title">Attack &amp; Detect</div>
<div class="desc">Fire SQLi, XSS, and path traversal payloads. Observe every hit as a True Positive in WAF logs — without blocking any traffic.</div>
<div class="tags"><span class="tag">SQLi</span> <span class="tag">XSS</span> <span class="tag">True Positive</span> <span class="tag">KQL</span></div>
</a>

<a class="lab-card" href="{{ '/labs/part3/' | relative_url }}">
<div class="num">Lab 3</div>
<div class="title">Prevention &amp; Tuning</div>
<div class="desc">Enable Prevention Mode, trigger a real False Positive on <code>O'Brien</code> search, then resolve it with a scoped Rule Exclusion.</div>
<div class="tags"><span class="tag">Prevention Mode</span> <span class="tag">False Positive</span> <span class="tag">Rule Exclusion</span></div>
</a>

<a class="lab-card" href="{{ '/labs/part4/' | relative_url }}">
<div class="num">Lab 4</div>
<div class="title">Custom Rules</div>
<div class="desc">Block <code>/admin</code> by IP, rate-limit login brute-force attempts, and geo-filter traffic by country — all with Custom Rules.</div>
<div class="tags"><span class="tag">Custom Rules</span> <span class="tag">Rate Limiting</span> <span class="tag">Geo-filter</span></div>
</a>

<a class="lab-card" href="{{ '/labs/part5/' | relative_url }}">
<div class="num">Lab 5</div>
<div class="title">Bot &amp; Observability</div>
<div class="desc">Enable Bot Manager, simulate known-bad bots, build KQL dashboards, create an alert rule, and wire WAF logs to Microsoft Sentinel.</div>
<div class="tags"><span class="tag">Bot Manager</span> <span class="tag">Sentinel</span> <span class="tag">Azure Monitor</span> <span class="tag">KQL</span></div>
</a>

<a class="lab-card" href="{{ '/labs/part6/' | relative_url }}">
<div class="num">Lab 6</div>
<div class="title">Fix the Code</div>
<div class="desc">Eliminate False Positives at the source — fix SQLi, XSS, and path traversal in the Flask app with parameterised queries and safe escaping. WAF defense-in-depth stays fully active.</div>
<div class="tags"><span class="tag">Secure Coding</span> <span class="tag">Parameterised SQL</span> <span class="tag">XSS Escaping</span> <span class="tag">Defense-in-Depth</span></div>
</a>
</div>

## Prerequisites

| Requirement | Notes |
|---|---|
| Azure subscription | Contributor role on a resource group |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`) | v2.50+ |
| [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd) (`azd`) | v1.9+ |
| Python 3.12+ | For local test scripts |
| bash | Git Bash on Windows is sufficient |

{: .warning }
> **Cost:** Application Gateway WAF_v2 costs approximately **$0.36/hr** plus gateway capacity units.
> Run `azd down` at the end of every session. App Service B1 and Azure SQL Free tier add minimal cost.

## Best Practices Coverage

Every recommendation from the [MS WAF best practices page](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/best-practices) is demonstrated:

| Best Practice | Lab |
|---|---|
| Enable the WAF | Lab 1 |
| Use WAF Policies (not legacy config) | Lab 1 |
| Use Detection Mode for initial tuning | Labs 1–2 |
| Tune with Rule Exclusions | Lab 3 |
| Use Prevention Mode in production | Lab 3 |
| Define WAF configuration as code (Bicep) | Lab 3 |
| Enable core rule sets (DRS 2.1) | Lab 1 |
| Use the latest ruleset version | Lab 1 |
| Enable bot management rules | Lab 5 |
| Geo-filter traffic | Lab 4 |
| Add diagnostic settings → Log Analytics | Lab 1 |
| Send logs to Microsoft Sentinel | Lab 5 |
| Fix code vulnerabilities (no Rule Exclusion needed) | Lab 6 |
