---
layout: default
title: Labs
nav_order: 2
has_children: true
permalink: /labs/
---

# Labs

Six hands-on labs that take you from WAF deployment to production-grade hardening — covering every recommendation from the [MS WAF best practices page](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/best-practices).

| Lab | Time | What you do |
|-----|------|-------------|
| [Lab 1 — Deploy & Baseline]({{ '/labs/part1/' | relative_url }}) | ~30 min | Deploy with `azd up`, verify connectivity, confirm Detection Mode |
| [Lab 2 — Attack & Detect]({{ '/labs/part2/' | relative_url }}) | ~20 min | Fire SQLi, XSS, path traversal — observe True Positives in WAF logs |
| [Lab 3 — Prevention & Tuning]({{ '/labs/part3/' | relative_url }}) | ~40 min | Enable Prevention Mode, resolve an O'Brien False Positive with Rule Exclusion |
| [Lab 4 — Custom Rules]({{ '/labs/part4/' | relative_url }}) | ~30 min | IP block, rate-limit, geo-filter with Custom Rules |
| [Lab 5 — Bot & Observability]({{ '/labs/part5/' | relative_url }}) | ~45 min | Bot Manager, KQL dashboards, alerting, Sentinel, `azd down` |
