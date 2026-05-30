#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ssh_target> <n8n_domain>"
  echo "Example: $0 root@65.109.64.152 liven8nleonyo.sellsystems.agency"
  exit 1
fi

SSH_TARGET="$1"
DOMAIN="$2"

SSH_CMD="ssh"
if [[ -n "${SSH_OPTS:-}" ]]; then
  SSH_CMD="ssh ${SSH_OPTS}"
fi

${SSH_CMD} "${SSH_TARGET}" bash <<EOF
set -euo pipefail
echo "[remote] n8n service status:"
systemctl --no-pager --full status n8n || true
echo "[remote] listening ports:"
ss -ltnp | grep -E '(:5678|:80|:443|:3000|:8080)' || true
echo "[remote] n8n env:"
if [[ -f /etc/n8n/n8n.env ]]; then
  grep -E '^(N8N_|NODE_ENV|N8N_PROTOCOL|N8N_EDITOR_BASE_URL|WEBHOOK_URL|N8N_USER_FOLDER)=' /etc/n8n/n8n.env
fi
EOF

echo "[remote] local health checks:"
curl -sk -I "https://${DOMAIN}/" | head -n 20 || true
curl -sk -I "https://${DOMAIN}/healthz" | head -n 20 || true
echo "[remote] local root and health fetch"
curl -sk "https://${DOMAIN}/healthz" | head -c 200 || true
echo
