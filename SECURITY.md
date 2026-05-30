# Security Policy

## Supported setup

This project assumes the main host owns TLS certificates and reverse-proxy security controls. The instance itself runs n8n over plain HTTP on port `80`.

## Reporting vulnerabilities

If you find a security issue, do not open a public issue. Use GitHub Security Advisories to report it privately.

Report includes:
- Deployment path (`main-host`, `instance`, or both).
- Exact command or script involved.
- Repro steps and impact.
- Relevant logs (sanitize credentials).

## Security baseline

- Keep `/etc/n8n/n8n.env` permissions restrictive (`chmod 600`).
- Rotate `N8N_ENCRYPTION_KEY` when reusing an image or snapshot.
- Use minimal SSH access for automation accounts.
- Keep wildcard certs on the main host only.
