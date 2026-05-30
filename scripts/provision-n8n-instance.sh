#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  provision-n8n-instance.sh <ssh_target> <n8n_public_domain> [n8n_user] [data_dir]

Examples:
  ./scripts/provision-n8n-instance.sh <SSH_TARGET> <N8N_PUBLIC_DOMAIN>
  ./scripts/provision-n8n-instance.sh <SSH_TARGET> <N8N_PUBLIC_DOMAIN> <N8N_USER> <N8N_DATA_DIR>

Optional env:
  SSH_OPTS  Extra ssh options (e.g. "-p 2222 -i ~/.ssh/id_rsa")
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SSH_TARGET="$1"
N8N_PUBLIC_DOMAIN="$2"
N8N_USER="${3:-root}"
N8N_DATA_DIR="${4:-/var/lib/n8n}"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-n8n-no-docker.sh"
PINNED_VERSION_EXPORT=""
ENCRYPTION_KEY_EXPORT=""

if [[ -n "${N8N_INSTALL_PINNED_VERSION:-}" ]]; then
  PINNED_VERSION_EXPORT="export N8N_INSTALL_PINNED_VERSION='${N8N_INSTALL_PINNED_VERSION}'"
fi
if [[ -n "${N8N_ENCRYPTION_KEY:-}" ]]; then
  ENCRYPTION_KEY_EXPORT="export N8N_ENCRYPTION_KEY='${N8N_ENCRYPTION_KEY}'"
fi

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
export N8N_PUBLIC_DOMAIN='${N8N_PUBLIC_DOMAIN}'
export N8N_USER='${N8N_USER}'
export N8N_DATA_DIR='${N8N_DATA_DIR}'
${PINNED_VERSION_EXPORT}
${ENCRYPTION_KEY_EXPORT}
/tmp/install-n8n-no-docker.sh
EOF

SAFE_NAME="${N8N_PUBLIC_DOMAIN//[^a-zA-Z0-9.-]/-}"
printf '[INFO] Generate a main-host config for this domain once instance backend is reachable.\n'
printf '       ./scripts/render-main-proxy-conf.sh %s INSTANCE_PRIVATE_IP /tmp/%s.conf\n' "${N8N_PUBLIC_DOMAIN}" "${SAFE_NAME//./-}"
printf '       ./scripts/configure-main-nginx-proxy.sh %s INSTANCE_PRIVATE_IP\n' "${N8N_PUBLIC_DOMAIN}"
printf "      backend port is fixed to 80 in this architecture.\n"
printf '       Verify: ./scripts/check-n8n-url.sh %s\n' "${N8N_PUBLIC_DOMAIN}"
