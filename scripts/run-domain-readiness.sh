#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <ssh_target> <n8n_public_domain> <instance_private_ip> [n8n_user] [data_dir]"
  echo "Example: $0 <SSH_TARGET> <N8N_PUBLIC_DOMAIN> <INSTANCE_PRIVATE_IP>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SSH_TARGET="$1"
N8N_PUBLIC_DOMAIN="$2"
INSTANCE_IP="$3"
N8N_USER="${4:-root}"
N8N_DATA_DIR="${5:-/var/lib/n8n}"

echo "[phase] deploy n8n"
"${SCRIPT_DIR}/provision-n8n-instance.sh" "${SSH_TARGET}" "${N8N_PUBLIC_DOMAIN}" "${N8N_USER}" "${N8N_DATA_DIR}"

echo "[phase] configure proxy on main host (local run)"
sudo "${SCRIPT_DIR}/configure-main-nginx-proxy.sh" "${N8N_PUBLIC_DOMAIN}" "${INSTANCE_IP}"

echo "[phase] verify service + public URL"
"${SCRIPT_DIR}/verify-remote-instance.sh" "${SSH_TARGET}" "${N8N_PUBLIC_DOMAIN}"
"${SCRIPT_DIR}/check-n8n-url.sh" "${N8N_PUBLIC_DOMAIN}"

echo "[phase] complete"
