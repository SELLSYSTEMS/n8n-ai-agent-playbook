#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[${BASENAME}] $*"
}

BASENAME="$(basename "$0")"
DOMAIN="${N8N_PUBLIC_DOMAIN:-}"
N8N_PORT="80"
N8N_USER="${N8N_USER:-root}"
N8N_DATA_DIR="${N8N_DATA_DIR:-/var/lib/n8n}"
N8N_ENV_DIR="/etc/n8n"
N8N_ENV_FILE="${N8N_ENV_DIR}/n8n.env"
N8N_SERVICE_FILE="/etc/systemd/system/n8n.service"
N8N_BINARY=""

if [[ -z "${DOMAIN}" ]]; then
  log "ERROR: set N8N_PUBLIC_DOMAIN before running."
  log "Example: export N8N_PUBLIC_DOMAIN=n8n.example.com"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  log "ERROR: run as root (required to bind N8N_PORT=80)."
  log "If you need unprivileged install, use N8N_PORT=5678 in this script and proxy to that port."
  exit 1
fi

if [[ "${N8N_USER}" != "root" && "${N8N_PORT}" == "80" ]]; then
  log "ERROR: non-root user cannot bind port 80 with this architecture."
  log "Set N8N_USER=root or change N8N_PORT in the script to 5678."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log "ERROR: this installer supports Debian/Ubuntu style systems."
  exit 1
fi

export N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY:-$(openssl rand -base64 48)}"
if [[ -z "${N8N_ENCRYPTION_KEY}" ]]; then
  log "ERROR: unable to generate N8N_ENCRYPTION_KEY."
  exit 1
fi

log "Installing system deps."
apt-get update
apt-get install -y git ca-certificates curl gnupg2 build-essential openssl

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y nodejs
else
  NODE_MAJOR="$(node -v | cut -d. -f1 | tr -cd 0-9)"
  if [[ "${NODE_MAJOR}" -lt 20 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
  fi
fi

if ! command -v npm >/dev/null 2>&1; then
  apt-get install -y npm
fi

NPM_PREFIX="$(npm config get prefix 2>/dev/null || true)"
NPM_PREFIX="${NPM_PREFIX:-/usr}"
if ! command -v realpath >/dev/null 2>&1; then
  NPM_PREFIX="$(echo "${NPM_PREFIX}" | sed 's#/*$##')"
else
  NPM_PREFIX="$(realpath "${NPM_PREFIX}" 2>/dev/null || echo "${NPM_PREFIX}")"
fi
GLOBAL_NODE_MODULES="${NPM_PREFIX%/}/lib/node_modules"
GLOBAL_BIN_DIR="${NPM_PREFIX%/}/bin"

if [[ -d "${GLOBAL_NODE_MODULES}" ]]; then
  log "Cleaning stale global n8n artifacts in ${GLOBAL_NODE_MODULES}."
  rm -rf "${GLOBAL_NODE_MODULES}/n8n"
  rm -rf "${GLOBAL_NODE_MODULES}"/.n8n-*
fi

log "Installing n8n globally."
if [[ -n "${N8N_INSTALL_PINNED_VERSION:-}" ]]; then
  npm install -g --no-fund --no-audit "n8n@${N8N_INSTALL_PINNED_VERSION}"
else
  npm install -g --no-fund --no-audit n8n
fi

if [[ -f "${GLOBAL_BIN_DIR}/n8n" ]]; then
  N8N_BINARY="${GLOBAL_BIN_DIR}/n8n"
else
  N8N_BINARY="$(command -v n8n || true)"
fi

if [[ -z "${N8N_BINARY}" ]]; then
  log "ERROR: cannot find n8n binary after npm install."
  log "Command path checked: ${GLOBAL_BIN_DIR}/n8n and command -v n8n."
  exit 1
fi

if [[ -n "$(command -v node)" ]]; then
  log "node version: $(node -v)"
fi

if [[ -n "${N8N_BINARY}" ]]; then
  ln -sf "${N8N_BINARY}" /usr/bin/n8n
fi

if ! getent passwd "${N8N_USER}" >/dev/null; then
  if [[ "${N8N_USER}" == "root" ]]; then
    log "INFO: using existing root account."
  else
    useradd --system --create-home --shell /usr/sbin/nologin "${N8N_USER}"
  fi
fi

mkdir -p "${N8N_DATA_DIR}" "${N8N_ENV_DIR}"
chown -R "${N8N_USER}:${N8N_USER}" "${N8N_DATA_DIR}"

cat > "${N8N_ENV_FILE}" <<EOF_ENV
NODE_ENV=production
N8N_PROTOCOL=http
N8N_HOST=0.0.0.0
N8N_LISTEN_ADDRESS=0.0.0.0
N8N_PORT=${N8N_PORT}
N8N_EDITOR_BASE_URL=https://${DOMAIN}
N8N_WEBHOOK_URL=https://${DOMAIN}
N8N_USER_FOLDER=${N8N_DATA_DIR}
N8N_PROXY_HOPS=1
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_LOG_LEVEL=info
N8N_SECURE_COOKIE=false
EOF_ENV

if [[ "${N8N_BASIC_AUTH_ACTIVE:-}" == "true" ]]; then
  if [[ -z "${N8N_BASIC_AUTH_USER:-}" || -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]]; then
    log "ERROR: N8N_BASIC_AUTH_ACTIVE=true but credentials missing."
    log "Set N8N_BASIC_AUTH_USER and N8N_BASIC_AUTH_PASSWORD."
    exit 1
  fi

  cat >> "${N8N_ENV_FILE}" <<EOF_AUTH
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
EOF_AUTH
fi

chmod 600 "${N8N_ENV_FILE}"

cat > "${N8N_SERVICE_FILE}" <<EOF_SERVICE
[Unit]
Description=n8n automation
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${N8N_USER}
WorkingDirectory=${N8N_DATA_DIR}
EnvironmentFile=${N8N_ENV_FILE}
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/env n8n
Restart=always
RestartSec=10
TimeoutStartSec=120
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF_SERVICE

systemctl daemon-reload
systemctl enable --now n8n || systemctl enable n8n
systemctl restart n8n || true

if ! systemctl is-active --quiet n8n; then
  log "WARNING: service not active after start; showing status."
  systemctl --no-pager --full status n8n || true
  exit 1
fi

log "Service status:"
systemctl --no-pager --full status n8n || true

log "Verifying local endpoint on ${N8N_PORT}."
if ! curl -fsS "http://127.0.0.1:${N8N_PORT}/healthz" >/tmp/n8n_health_check.json; then
  log "FAIL: local health check failed. See /tmp/n8n_health_check.json for details."
  exit 1
fi

log "Health response: $(cat /tmp/n8n_health_check.json | head -c 200)"

log "done"
log "Open https://${DOMAIN} on the main host after proxying to this instance endpoint."
