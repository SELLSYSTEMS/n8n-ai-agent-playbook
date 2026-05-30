# AGENTS: n8n No-Docker Installation Agent Notes

## Non-negotiable architecture

- No Docker.
- HTTPS is always terminated on the main host.
- Main host proxy target is always the instance on port `80`.
- Public domain must be opened as `https://<N8N_PUBLIC_DOMAIN>/`.
- Instance-side health check is `http://127.0.0.1/healthz`.

## Required input for instance install

- Set exactly one required variable before running `scripts/install-n8n-no-docker.sh`:
  - `N8N_PUBLIC_DOMAIN`

All future instance deployments should vary only by this value.

## Standard install flow

1. On the instance, set `N8N_PUBLIC_DOMAIN` and run
   `sudo ./scripts/install-n8n-no-docker.sh`.
2. On the main host, proxy `https://<N8N_PUBLIC_DOMAIN>` to instance private IP `:80`.
3. Verify with `./scripts/check-n8n-url.sh <N8N_PUBLIC_DOMAIN>`.

## Why this exists

This contract avoids per-agent drift:

- one instance-domain input,
- fixed port behavior,
- wildcard HTTPS handled by main host,
- identical process for every new agent/domain.

## Field notes (already applied in this playbook)

- `npm` global install can leave stale artifacts on interrupted installs (for example `/usr/lib/node_modules/.n8n-*`), so the installer performs a safe global cleanup before reinstall.
- The installer uses `n8n` via `PATH` (`ExecStart=/usr/bin/env n8n`) so it works whether npm places the binary in `/usr/bin` or `/usr/local/bin`.
- Health verification uses `/healthz` (not `/rest/healthz`) for this n8n version.
- If you see a missing binary after install, restart the install script; it is now designed to rebuild the runtime path consistently before enabling the service.
