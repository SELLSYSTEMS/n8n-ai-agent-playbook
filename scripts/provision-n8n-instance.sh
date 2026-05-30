#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  provision-n8n-instance.sh <ssh_target> <n8n_domain> <n8n_port> [n8n_user] [data_dir]

Examples:
  ./scripts/provision-n8n-instance.sh root@65.109.64.152 liven8nleonyo.sellsystems.agency 5678
  ./scripts/provision-n8n-instance.sh admin@65.109.64.152 liven8nleonyo.sellsystems.agency 5678 n8n

Optional env:
  SSH_OPTS  Extra ssh options (e.g. "-p 2222 -i ~/.ssh/id_rsa")
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

SSH_TARGET="$1"
N8N_DOMAIN="$2"
N8N_PORT="$3"
N8N_USER="${4:-n8n}"
N8N_DATA_DIR="${5:-/var/lib/n8n}"
SCRIPT_SRC="/home/n8n/scripts/install-n8n-no-docker.sh"

if [[ ! -f "${SCRIPT_SRC}" ]]; then
  echo "ERROR: missing installer script at ${SCRIPT_SRC}"
  exit 1
fi

SSH_CMD="ssh"
SCP_CMD="scp"
if [[ -n "${SSH_OPTS:-}" ]]; then
  SSH_CMD="ssh ${SSH_OPTS}"
  SCP_CMD="scp ${SSH_OPTS}"
fi

if ! command -v ssh >/dev/null; then
  echo "ERROR: ssh not found on local system."
  exit 1
fi

echo "[INFO] Copying installer to ${SSH_TARGET}"
if ! ${SCP_CMD} "${SCRIPT_SRC}" "${SSH_TARGET}:/tmp/install-n8n-no-docker.sh"; then
  echo "INFO: SCP failed; falling back to SSH here-doc transfer"
  SCRIPT_B64="$(base64 -w0 "${SCRIPT_SRC}")"
  ${SSH_CMD} "${SSH_TARGET}" \
    "cat > /tmp/install-n8n-no-docker.b64 <<'EOF' && base64 -d /tmp/install-n8n-no-docker.b64 > /tmp/install-n8n-no-docker.sh\n${SCRIPT_B64}\nEOF\nchmod +x /tmp/install-n8n-no-docker.sh" \
    || { echo "ERROR: failed to transfer installer"; exit 1; }
fi

echo "[INFO] Running remote install on ${SSH_TARGET}"
${SSH_CMD} "${SSH_TARGET}" bash <<EOF
set -euo pipefail
export N8N_INSTANCE_DOMAIN='${N8N_DOMAIN}'
export N8N_PORT='${N8N_PORT}'
export N8N_USER='${N8N_USER}'
export N8N_DATA_DIR='${N8N_DATA_DIR}'
/tmp/install-n8n-no-docker.sh
EOF

echo "[INFO] Generate proxy config and apply on main host:"
echo "  ./scripts/render-main-proxy-conf.sh ${N8N_DOMAIN} <INSTANCE_INTERNAL_IP> ${N8N_PORT} /tmp/n8n-proxy.conf"
