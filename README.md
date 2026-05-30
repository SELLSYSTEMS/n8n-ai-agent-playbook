# n8n No-Docker Playbook (Reusable for New Domains)

This playbook is for non-Docker n8n installs behind a main host reverse proxy with existing HTTPS termination.

## Architecture (enforced)

- Public endpoint: `https://<N8N_PUBLIC_DOMAIN>/`
- Main host handles TLS with wildcard certificate and redirects `http -> https`.
- Main host proxies to instance on port `80`.
- Instance runs n8n over plain HTTP on port `80`.
- Public-facing n8n/webhook URLs are forced to `https://<N8N_PUBLIC_DOMAIN>`.

> Important: this is the contract that should be reused for every new instance.

## Files

- `scripts/install-n8n-no-docker.sh` — installs and configures n8n on the instance (no Docker).
- `scripts/provision-n8n-instance.sh` — pushes installer and runs it remotely.
- `scripts/configure-main-nginx-proxy.sh` — writes main-host nginx config and reloads nginx.
- `scripts/render-main-proxy-conf.sh` — writes a ready-to-apply nginx config snippet.
- `scripts/run-domain-readiness.sh` — full flow: remote install, proxy config, checks.
- `scripts/verify-remote-instance.sh` — health/status check on the target instance and public URL.
- `scripts/check-n8n-url.sh` — HTTPS endpoint readiness checker.
- `templates/n8n-proxy-main-host.conf` — nginx proxy template.
- `templates/n8n-systemd.service` — example systemd unit (the installer renders its own file).

## 1) Instance install (required input)

On the instance, run:

```bash
export N8N_PUBLIC_DOMAIN="<N8N_PUBLIC_DOMAIN>"
cd /home/n8n
sudo ./scripts/install-n8n-no-docker.sh
```

Notes:
- `N8N_PUBLIC_DOMAIN` is the only required variable for the instance installer.
- The instance is configured for HTTP on port `80` and expects the main host to do TLS.

## 2) Main host proxy (mandatory)

### Option A: render then apply manually

```bash
INSTANCE_PRIVATE_IP="<INSTANCE_PRIVATE_IP>"
./scripts/render-main-proxy-conf.sh \
  ${N8N_PUBLIC_DOMAIN} \
  ${INSTANCE_PRIVATE_IP} \
  /tmp/n8n.conf
```

Apply `/tmp/liven8n.conf` in your main host nginx config and reload nginx.

### Option B: local apply helper (if run on main host)

```bash
INSTANCE_PRIVATE_IP="<INSTANCE_PRIVATE_IP>"
sudo ./scripts/configure-main-nginx-proxy.sh \
  ${N8N_PUBLIC_DOMAIN} \
  ${INSTANCE_PRIVATE_IP}
```

## 3) Full one-command flow (agent-friendly)

```bash
export SSH_OPTS="-i ~/.ssh/id_rsa -o StrictHostKeyChecking=no"
INSTANCE_SSH_TARGET="root@<INSTANCE_PRIVATE_IP>"
./scripts/run-domain-readiness.sh \
  ${INSTANCE_SSH_TARGET} \
  ${N8N_PUBLIC_DOMAIN} \
  ${INSTANCE_PRIVATE_IP}
```

## 4) Validation

```bash
./scripts/check-n8n-url.sh <N8N_PUBLIC_DOMAIN>
```

Expect:
- HTTPS endpoint responds `200` and serves n8n HTML.
- `/healthz` responds with `200`.

## 5) Reuse for future domains/agents

For each new instance/domain, change only:

- `N8N_PUBLIC_DOMAIN` in instance install
- instance private IP in main-host proxy command

Everything else stays the same.

- No Docker.
- No certificate installation in this playbook (main host SSL already exists).
- No extra placeholders beyond `<N8N_PUBLIC_DOMAIN>` / `<INSTANCE_PRIVATE_IP>` in this playbook.

## What changed from common failure patterns

- Installer now handles interrupted `npm` installs by removing stale `n8n` package artifacts before reinstalling.
- Installer now expects and validates:
  - `n8n` service binary available on PATH (root or local global bin),
  - service file with `ExecStart=/usr/bin/env n8n`,
  - `http://127.0.0.1/healthz` as the local readiness check.
- Main-host proxy and remote checks are documented for the fixed path and port model (`:80` on instance, HTTPS at `https://<N8N_PUBLIC_DOMAIN>/`).
