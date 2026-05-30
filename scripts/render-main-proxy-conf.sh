#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <domain> <instance_host> <instance_port> <output_file>"
  echo "Example: $0 liven8nleonyo.sellsystems.agency 10.0.0.10 5678 /tmp/n8n.conf"
  exit 1
fi

DOMAIN="$1"
INSTANCE_HOST="$2"
INSTANCE_PORT="$3"
OUTPUT="$4"

cat > "${OUTPUT}" <<EOF
# Generated n8n reverse proxy for ${DOMAIN}
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\${host}\${request_uri};
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    # Main host SSL certificate is already in place (wildcard certificate).
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

echo "Generated ${OUTPUT}"
