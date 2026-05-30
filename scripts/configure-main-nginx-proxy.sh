#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <domain> <instance_host> <instance_port> [domain_file_name]"
  echo "Example: $0 liven8nleonyo.sellsystems.agency 127.0.0.1 5678 liven8nleonyo"
  exit 1
fi

DOMAIN="$1"
INSTANCE_HOST="$2"
INSTANCE_PORT="$3"
NAME="${4:-${DOMAIN//./-}}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (or with sudo)."
  exit 1
fi

if [[ ! -d /etc/nginx ]]; then
  echo "nginx not installed at /etc/nginx"
  exit 1
fi

if [[ -d /etc/nginx/sites-available && -d /etc/nginx/sites-enabled ]]; then
  TARGET_DIR="/etc/nginx/sites-available"
  LINK_DIR="/etc/nginx/sites-enabled"
  FILE="/etc/nginx/sites-available/${NAME}.conf"
elif [[ -d /etc/nginx/conf.d ]]; then
  TARGET_DIR="/etc/nginx/conf.d"
  LINK_DIR=""
  FILE="/etc/nginx/conf.d/${NAME}.conf"
else
  echo "Could not locate standard nginx config location."
  exit 1
fi

cat > "${FILE}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    # SSL files are expected to be configured on this host.
    # ssl_certificate /path/to/fullchain.pem;
    # ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://${INSTANCE_HOST}:${INSTANCE_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF

if [[ -n "${LINK_DIR}" ]]; then
  ln -sf "${FILE}" "${LINK_DIR}/${NAME}.conf"
fi

if ! nginx -t; then
  echo "Nginx config test failed. Revert as needed: rm ${FILE}"
  exit 1
fi

systemctl reload nginx
echo "Configured ${DOMAIN} in ${FILE} and reloaded nginx."
