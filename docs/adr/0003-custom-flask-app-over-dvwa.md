# Use a purpose-built Flask app instead of DVWA or OWASP Juice Shop

The lab uses a custom Python Flask application with intentionally vulnerable endpoints rather than a pre-built vulnerable app (DVWA, OWASP Juice Shop, WebGoat). Pre-built apps carry attack surfaces far beyond what the WAF labs need, producing noisy WAF logs that obscure the specific rules being demonstrated. A purpose-built app exposes exactly the vulnerabilities mapped to each lab part (SQLi on `/search`, XSS reflection, path traversal on `/file`, brute-force target on `/login`), making the relationship between attack payload → WAF rule → log entry unambiguous. It also connects to a real Azure SQL database, making SQL injection demonstrations genuinely realistic rather than simulated.

## Considered Options

- **DVWA** — PHP/Docker, rich attack surface but noisy and disconnected from Azure SQL
- **OWASP Juice Shop** — Node.js, modern UX, but many vulnerabilities are app-layer not WAF-layer, making WAF rule mapping unclear
