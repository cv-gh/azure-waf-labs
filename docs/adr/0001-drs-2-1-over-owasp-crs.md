# Use DRS 2.1 as the WAF ruleset instead of OWASP CRS 3.2

Microsoft's Default Ruleset (DRS) 2.1 is the currently recommended ruleset for Azure Application Gateway WAF, superseding OWASP CRS 3.2. We use DRS 2.1 throughout all labs because the Microsoft WAF best practices page explicitly recommends using the latest ruleset version, and DRS 2.1 includes Azure-specific threat intelligence additions on top of the OWASP base. Using CRS 3.2 would teach a pattern Microsoft is actively moving away from and would produce different rule IDs in logs than what practitioners see on new deployments.

## Considered Options

- **OWASP CRS 3.2** — more externally documented, but older and being superseded
- **OWASP CRS 3.1** — legacy, end-of-life, rejected immediately
