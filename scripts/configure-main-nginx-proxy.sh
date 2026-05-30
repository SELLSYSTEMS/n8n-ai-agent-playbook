#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <domain> <instance_host> [domain_file_name]"
  echo "Example: $0 <N8N_PUBLIC_DOMAIN> <INSTANCE_PRIVATE_IP> [safe_name]"
  exit 1
fi

DOMAIN="$1"
INSTANCE_HOST="$2"
NAME="${3:-${DOMAIN//./-}}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (or with sudo)."
  exit 1
fi

if [[ ! -d /etc/nginx ]]; then
  echo "nginx not installed at /etc/nginx"
  exit 1
fi

if [[ -d /etc/nginx/sites-available && -d /etc/nginx/sites-enabled ]]; then
  FILE="/etc/nginx/sites-available/${NAME}.conf"
  TARGET_LINK="/etc/nginx/sites-enabled/${NAME}.conf"
elif [[ -d /etc/nginx/conf.d ]]; then
  FILE="/etc/nginx/conf.d/${NAME}.conf"
  TARGET_LINK=""
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

    # SSL certificates are managed on the main host.
    # ssl_certificate /path/to/fullchain.pem;
    # ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://${INSTANCE_HOST}:80;
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

if [[ -n "${TARGET_LINK}" ]]; then
  ln -sf "${FILE}" "${TARGET_LINK}"
fi

if ! nginx -t; then
  echo "Nginx config test failed. Revert as needed: rm ${FILE}"
  exit 1
fi

systemctl reload nginx
echo "Configured ${DOMAIN} in ${FILE} and reloaded nginx."
