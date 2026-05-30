# n8n No-Docker Playbook (Reusable for New Domains)

This playbook is for non-Docker n8n installs behind a main host reverse proxy with existing HTTPS termination.

## Architecture (enforced)

- Public endpoint: `https://<N8N_PUBLIC_DOMAIN>/`
- Main host handles TLS with wildcard certificate and redirects `http -> https`.
- Main host proxies to instance on port `80`.
- Instance runs n8n over plain HTTP on port `80`.
- Public-facing n8n/webhook URLs are forced to `https://<N8N_PUBLIC_DOMAIN>`.

> Important: this is the contract that should be reused for every new instance.

## Repository structure

```text
.
├─ AGENTS.md                         # non-negotiable architecture contract for all agents
├─ README.md                         # install + runbook + reusable deployment pattern
├─ notes/
│  └─ installation-log.md            # operational notes
├─ scripts/
│  ├─ install-n8n-no-docker.sh       # instance installer (source of truth)
│  ├─ provision-n8n-instance.sh      # remote install helper
│  ├─ configure-main-nginx-proxy.sh  # apply main-host nginx snippet
│  ├─ render-main-proxy-conf.sh       # render-ready nginx config file
│  ├─ run-domain-readiness.sh         # full end-to-end helper flow
│  ├─ verify-remote-instance.sh       # remote service readiness checks
│  ├─ check-n8n-url.sh               # public HTTPS validation
│  ├─ log-issue.sh                   # local log helper
│  └─ ...
└─ templates/
   ├─ n8n-proxy-main-host.conf      # nginx template for main host
   └─ n8n-systemd.service           # example unit; installer writes/uses unit config
```

## Files and purpose

- `AGENTS.md`
  - Canonical operational contract for how all future instances must be deployed.
- `README.md`
  - Reuse guide and commands for new domains/instances.
- `notes/installation-log.md`
  - Reference notes and known environment facts.
- `scripts/install-n8n-no-docker.sh`
  - Installs and configures n8n on instance (no Docker).
- `scripts/provision-n8n-instance.sh`
  - Pushes installer and runs it on remote host.
- `scripts/configure-main-nginx-proxy.sh`
  - Writes main-host nginx config and reloads nginx.
- `scripts/render-main-proxy-conf.sh`
  - Generates nginx config file for a specific domain+private IP.
- `scripts/run-domain-readiness.sh`
  - Executes end-to-end flow for install + proxy + checks.
- `scripts/verify-remote-instance.sh`
  - Checks instance service health and endpoint reachability.
- `scripts/check-n8n-url.sh`
  - Checks public domain readiness (`https://<N8N_PUBLIC_DOMAIN>/` and `/healthz`).
- `templates/n8n-proxy-main-host.conf`
  - Proxy template used by helper scripts.
- `templates/n8n-systemd.service`
  - Service template used by installer.

## What changed from common failure patterns

- Installer now handles interrupted `npm` installs by removing stale `n8n` artifacts before reinstalling.
- Installer validates runtime path (`/usr/bin/env n8n`) and uses local binary detection.
- Health checks use `/healthz` (not `/rest/healthz`) for this version.

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

Apply `/tmp/n8n.conf` in your main host nginx config and reload nginx.

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
- No extra placeholders are required beyond `<N8N_PUBLIC_DOMAIN>` and `<INSTANCE_PRIVATE_IP>`.
