#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <domain> <instance_host> <output_file>"
  echo "Example: $0 <N8N_PUBLIC_DOMAIN> <INSTANCE_PRIVATE_IP> /tmp/n8n.conf"
  exit 1
fi

DOMAIN="$1"
INSTANCE_HOST="$2"
OUTPUT="$3"

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

echo "Generated ${OUTPUT}"
