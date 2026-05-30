#!/usr/bin/env bash

set -euo pipefail

DOMAIN="${N8N_INSTANCE_DOMAIN:-}"
PORT="${N8N_PORT:-5678}"
N8N_USER="${N8N_USER:-n8n}"
N8N_DATA_DIR="${N8N_DATA_DIR:-/var/lib/n8n}"
N8N_ENV_DIR="/etc/n8n"
N8N_ENV_FILE="${N8N_ENV_DIR}/n8n.env"
N8N_SERVICE_FILE="/etc/systemd/system/n8n.service"
BASENAME="$(basename "$0")"

if [[ -z "${DOMAIN}" ]]; then
  echo "[${BASENAME}] ERROR: set N8N_INSTANCE_DOMAIN before running."
  echo "Example: export N8N_INSTANCE_DOMAIN=n8n.example.com"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "[${BASENAME}] ERROR: run as root or with sudo."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "[${BASENAME}] ERROR: this installer supports Debian/Ubuntu style systems."
  exit 1
fi

if [[ -z "${N8N_ENCRYPTION_KEY:-}" ]]; then
  export N8N_ENCRYPTION_KEY
  N8N_ENCRYPTION_KEY="$(openssl rand -base64 48)"
  echo "[${BASENAME}] INFO: generated N8N_ENCRYPTION_KEY (saved in ${N8N_ENV_FILE})."
fi

apt-get update
apt-get install -y git ca-certificates curl gnupg2 build-essential

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

if [[ -n "${N8N_INSTALL_PINNED_VERSION:-}" ]]; then
  npm install -g "n8n@${N8N_INSTALL_PINNED_VERSION}"
else
  npm install -g n8n
fi

if ! getent passwd "${N8N_USER}" >/dev/null; then
  useradd --system --create-home --shell /usr/sbin/nologin "${N8N_USER}"
fi

mkdir -p "${N8N_DATA_DIR}" "${N8N_ENV_DIR}"
chown -R "${N8N_USER}:${N8N_USER}" "${N8N_DATA_DIR}"

cat > "${N8N_ENV_FILE}" <<EOF
NODE_ENV=production
N8N_PROTOCOL=https
N8N_HOST=0.0.0.0
N8N_LISTEN_ADDRESS=0.0.0.0
N8N_PORT=${PORT}
N8N_EDITOR_BASE_URL=https://${DOMAIN}
WEBHOOK_URL=https://${DOMAIN}
N8N_USER_FOLDER=${N8N_DATA_DIR}
N8N_PROXY_HOPS=1
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_LOG_LEVEL=info
EOF

if [[ "${N8N_BASIC_AUTH_ACTIVE:-}" == "true" ]]; then
  if [[ -z "${N8N_BASIC_AUTH_USER:-}" || -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]]; then
    echo "[${BASENAME}] ERROR: N8N_BASIC_AUTH_ACTIVE=true but credentials missing."
    echo "Set N8N_BASIC_AUTH_USER and N8N_BASIC_AUTH_PASSWORD."
    exit 1
  fi
  cat >> "${N8N_ENV_FILE}" <<EOF
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
EOF
fi

chmod 600 "${N8N_ENV_FILE}"

N8N_BINARY="$(command -v n8n)"
if [[ -z "${N8N_BINARY}" ]]; then
  echo "[${BASENAME}] ERROR: cannot find n8n binary after npm install."
  exit 1
fi

cat > "${N8N_SERVICE_FILE}" <<EOF
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
ExecStart=${N8N_BINARY}
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now n8n

sleep 2
echo "[${BASENAME}] status"
systemctl --no-pager --full status n8n || true

echo "[${BASENAME}] verify local HTTP endpoint"
curl -sS "http://127.0.0.1:${PORT}/healthz" | sed -n '1,5p'

echo "[${BASENAME}] done"
echo "Open https://${DOMAIN} on the main host after proxying to this instance endpoint."
