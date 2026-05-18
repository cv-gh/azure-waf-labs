# Azure WAF Lab

A multi-part hands-on lab for demonstrating Azure Application Gateway WAF capabilities — deploying, attacking, detecting, tuning, and hardening a vulnerable web application.

## Language

**Lab**:
A self-contained exercise part with a consistent structure: deploy/configure, attack, observe, fix. Five labs exist, each building on the previous.
_Avoid_: Module, exercise, chapter

**Vulnerable App**:
The purpose-built Python Flask application deployed behind the WAF. It exposes intentionally insecure endpoints to enable realistic attack demonstrations.
_Avoid_: Target app, sample app, demo app

**True Positive (TP)**:
A WAF block of a genuinely malicious request — the correct outcome. Labs 2 and 3 demonstrate TPs by firing known attack payloads.
_Avoid_: Correct block, attack blocked

**False Positive (FP)**:
A WAF block of a legitimate request — an incorrect outcome caused by an overly broad rule match. Lab 3 introduces a deliberate FP (product search for `O'Brien`) and teaches how to resolve it.
_Avoid_: False alarm, incorrect block

**Rule Exclusion**:
A WAF configuration that prevents a specific rule (or rule group) from evaluating a specific request element (e.g., query parameter `q`). The mechanism for resolving FPs without disabling rules entirely.
_Avoid_: Exception, whitelist, bypass

**Detection Mode**:
WAF operating mode that logs matched requests but does not block them. Used in Labs 1 and 2 to observe attack signatures without disrupting traffic.
_Avoid_: Audit mode, passive mode, monitor mode

**Prevention Mode**:
WAF operating mode that actively blocks requests matching rules. Enabled in Lab 3 after initial tuning. The production-ready state.
_Avoid_: Block mode, active mode, enforcement mode

**DRS**:
Default Ruleset — Microsoft's managed WAF ruleset (version 2.1), based on OWASP CRS with Azure-specific additions. The ruleset used throughout all labs.
_Avoid_: CRS, OWASP rules, managed rules (use only when referring to the category, not the specific version)

**WAF Policy**:
The Azure resource (`Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies`) that encapsulates ruleset version, rule exclusions, custom rules, and mode. Managed as Bicep code per best practice.
_Avoid_: WAF config, WAF settings, firewall policy

**Tuning**:
The iterative process of adding scoped Rule Exclusions to a WAF Policy to eliminate False Positives without reducing True Positive coverage. Lab 3 is dedicated to this.
_Avoid_: Configuring, whitelisting, adjusting

**Custom Rule**:
A user-authored WAF rule evaluated before managed rules. Used in Lab 4 for IP blocking, rate limiting, and geo-filtering.
_Avoid_: User rule, manual rule, override rule

**Attack Script**:
A shell script (`scripts/attack-partN.sh`) that fires all attack payloads for a given lab part in sequence. Each script is paired with curl one-liners in the docs that expose the raw HTTP request.
_Avoid_: Test script, payload script

## Architecture

```
Internet → App Gateway (WAF Policy, DRS 2.1) → App Service (Flask) → Azure SQL Database (Free tier)
```

- App Service authenticates to Azure SQL via **System-Assigned Managed Identity** (no connection strings)
- Infrastructure provisioned with **Bicep** via **Azure Developer CLI (`azd`)**
- WAF policy changes applied with **Azure CLI** during lab exercises

## Relationships

- A **WAF Policy** contains one **DRS** version, zero or more **Rule Exclusions**, and zero or more **Custom Rules**
- A **Lab** produces either a **True Positive** or a **False Positive** (or both) as its observable outcome
- **Tuning** resolves a **False Positive** by adding a scoped **Rule Exclusion** to the **WAF Policy**
- **Detection Mode** precedes **Prevention Mode** — Labs 1–2 use Detection, Labs 3–5 use Prevention

## Example dialogue

> **Practitioner:** "The WAF is blocking our product search for customers with apostrophes in their names."
> **Lab:** "That's a **False Positive** — rule `942100` matched the apostrophe as a SQL injection character. We'll add a **Rule Exclusion** scoped to the `q` query parameter. This is **Tuning**, not disabling the rule."

## Flagged ambiguities

- "Managed rules" is used in Microsoft docs to mean both the DRS ruleset category and the specific DRS version — in this project, **DRS** refers specifically to DRS 2.1, and "managed rules" refers to the category.
