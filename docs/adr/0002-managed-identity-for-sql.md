# Use Managed Identity for App Service to Azure SQL authentication

The Flask app authenticates to Azure SQL using a System-Assigned Managed Identity rather than a username/password connection string. A lab teaching security best practices (WAF hardening) must not simultaneously demonstrate the anti-pattern of storing database credentials in application settings. Managed Identity eliminates the credential surface entirely and is the approach Microsoft recommends for App Service to Azure SQL connectivity. The Bicep template handles the role assignment (`db_datareader`, `db_datawriter`) so learners see the full passwordless pattern as code.

## Considered Options

- **Connection string in App Settings** — simpler Bicep, but teaches credential management as an afterthought in a security-focused lab
