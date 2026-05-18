# Use Azure Developer CLI (azd) as the lab deployment mechanism

Lab infrastructure is provisioned and torn down via `azd up` / `azd down` rather than raw `az deployment group create` or portal clicks. `azd` provides a single-command deploy experience appropriate for practitioner-focused labs, standardizes the project structure (`azure.yaml`, `infra/`, `src/`), and handles environment variable injection (App Service settings, SQL connection info) automatically. This reduces Part 1 setup from a multi-step CLI sequence to one command, letting labs focus on WAF concepts rather than deployment mechanics. WAF policy changes within labs (Parts 2–5) are still applied via `az` CLI commands to keep the tuning workflow interactive and visible.

## Considered Options

- **Raw `az deployment group create`** — more explicit but more steps; worse first-run experience
- **Azure Portal** — no repeatability, contradicts the "WAF as code" best practice
- **Terraform** — viable but adds HCL as a second language and state management overhead for a lab context
