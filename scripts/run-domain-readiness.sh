#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <ssh_target> <n8n_domain> <instance_private_ip> [n8n_port=5678] [n8n_user=n8n] [data_dir=/var/lib/n8n]"
  echo "Example: $0 root@65.109.64.152 liven8nleonyo.sellsystems.agency 10.0.0.15 5678"
  exit 1
fi

SSH_TARGET="$1"
N8N_DOMAIN="$2"
INSTANCE_IP="$3"
N8N_PORT="${4:-5678}"
N8N_USER="${5:-n8n}"
N8N_DATA_DIR="${6:-/var/lib/n8n}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[phase] deploy n8n"
"${SCRIPT_DIR}/provision-n8n-instance.sh" "${SSH_TARGET}" "${N8N_DOMAIN}" "${N8N_PORT}" "${N8N_USER}" "${N8N_DATA_DIR}"

echo "[phase] configure proxy on main host (local run)"
sudo "${SCRIPT_DIR}/configure-main-nginx-proxy.sh" "${N8N_DOMAIN}" "${INSTANCE_IP}" "${N8N_PORT}"

echo "[phase] verify service + public URL"
"${SCRIPT_DIR}/verify-remote-instance.sh" "${SSH_TARGET}" "${N8N_DOMAIN}"
"${SCRIPT_DIR}/check-n8n-url.sh" "${N8N_DOMAIN}"

echo "[phase] complete"
