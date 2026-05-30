# n8n No-Docker Playbook (Reusable for New Domains)

This playbook is for non-Docker n8n installs behind a main host reverse proxy with existing HTTPS termination.

## Architecture (enforced)

- No Docker.
- Public endpoint: `https://<N8N_PUBLIC_DOMAIN>/`.
- HTTPS is always terminated on the main host using an existing wildcard certificate.
- Main host proxy target is always `instance_private_ip:80`.
- Instance runs n8n on plain HTTP `80` (`N8N_PROTOCOL=http`).
- Public-facing URLs are forced to `https://<N8N_PUBLIC_DOMAIN>`.

> This contract is mandatory and must be reused for every new instance.

## Repository structure

```text
.
├─ AGENTS.md                         # non-negotiable deployment contract for all agents
├─ README.md                         # runbook + reusable deployment pattern
├─ CONTRIBUTING.md                   # contribution and change rules
├─ SECURITY.md                       # vulnerability handling and reporting
├─ notes/
│  └─ installation-log.md            # operational notes
├─ docs/
│  └─ agent-reusable-operations.md   # deployment modes, assumptions, agent handoff notes
├─ scripts/
│  ├─ install-n8n-no-docker.sh       # instance installer (source of truth)
│  ├─ provision-n8n-instance.sh      # remote install helper
│  ├─ configure-main-nginx-proxy.sh  # apply main-host nginx snippet
│  ├─ render-main-proxy-conf.sh       # render-ready nginx config file
│  ├─ run-domain-readiness.sh         # full end-to-end helper flow
│  ├─ verify-remote-instance.sh       # remote service and endpoint checks
│  ├─ check-n8n-url.sh               # public HTTPS validation
│  └─ log-issue.sh                   # local issue log helper
├─ templates/
│  ├─ n8n-proxy-main-host.conf      # nginx template for main host
│  └─ n8n-systemd.service           # unit template used by installer
└─ .github/
   ├─ workflows/ci.yml               # repository quality gates
   └─ ISSUE_TEMPLATE/*               # issue reporting templates
```

## What changed from common failure patterns

- Installer clears stale global n8n artifacts before reinstalling.
- Service uses `N8N_PORT=80` and `ExecStart=/usr/bin/env n8n` for consistent binary resolution.
- Health verification uses `/healthz` to match this n8n runtime behavior.
- Proxy is fixed to plain HTTP on `80` and never depends on per-instance domain placeholders.

## 1) Instance install (required input)

On the instance, run:

```bash
export N8N_PUBLIC_DOMAIN="<N8N_PUBLIC_DOMAIN>"
sudo ./scripts/install-n8n-no-docker.sh
```

Notes:
- `N8N_PUBLIC_DOMAIN` is the only required environment variable for the instance.
- If needed, override `N8N_USER` and `N8N_DATA_DIR`, but keep `N8N_PORT` as `80`.

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

### Option B: local apply helper (on main host)

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
- HTTPS endpoint returns `200` and serves n8n page (not default Nginx page).
- `/healthz` returns `200`.

## 5) Deployment modes (for agent reuse)

- `install`: `install-n8n-no-docker.sh` with `N8N_PUBLIC_DOMAIN`.
- `proxy`: `configure-main-nginx-proxy.sh` with `N8N_PUBLIC_DOMAIN` and instance private IP.
- `verify`: `verify-remote-instance.sh` + `check-n8n-url.sh`.
- `full`: `run-domain-readiness.sh` for install + proxy + verify.

For every new instance:
- only `N8N_PUBLIC_DOMAIN` and instance private IP change.
- scripts and structure stay the same.

## Reuse guardrails

- No Docker usage.
- No certificate installation in this playbook (handled on main host).
- Keep wildcard SSL assumptions unchanged.
- Avoid adding per-agent variables unless they are truly instance-unique.
