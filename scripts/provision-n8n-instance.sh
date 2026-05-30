#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <ssh_target> <n8n_domain> <n8n_port> [n8n_user=n8n] [data_dir=/var/lib/n8n]"
  echo "Example: $0 root@65.109.64.152 liven8nleonyo.sellsystems.agency 5678"
  exit 1
fi

SSH_TARGET="$1"
N8N_DOMAIN="$2"
N8N_PORT="$3"
N8N_USER="${4:-n8n}"
N8N_DATA_DIR="${5:-/var/lib/n8n}"

SCRIPT_SRC="/home/n8n/scripts/install-n8n-no-docker.sh"

if [[ ! -f "${SCRIPT_SRC}" ]]; then
  echo "Missing installer script at ${SCRIPT_SRC}"
  exit 1
fi

echo "[INFO] Pushing installer to ${SSH_TARGET}"
scp "${SCRIPT_SRC}" "${SSH_TARGET}:/tmp/install-n8n-no-docker.sh"

echo "[INFO] Running remote install"
ssh "${SSH_TARGET}" "\
  chmod +x /tmp/install-n8n-no-docker.sh && \
  N8N_INSTANCE_DOMAIN='${N8N_DOMAIN}' \
  N8N_PORT='${N8N_PORT}' \
  N8N_USER='${N8N_USER}' \
  N8N_DATA_DIR='${N8N_DATA_DIR}' \
  /tmp/install-n8n-no-docker.sh"

echo "[INFO] Optional: generate proxy config locally and apply on main host"
echo "    ./scripts/render-main-proxy-conf.sh ${N8N_DOMAIN} <INSTANCE_INTERNAL_IP> ${N8N_PORT} /tmp/n8n-proxy.conf"
