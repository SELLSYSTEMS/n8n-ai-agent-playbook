#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <https-domain>"
  exit 1
fi

DOMAIN="$1"
set +e

echo "Checking domain: ${DOMAIN}"

HTTP_STATUS="$(curl -sk -o /tmp/n8n_root.html -w "%{http_code}" "https://${DOMAIN}/" )"
if [[ "${HTTP_STATUS}" != "200" ]]; then
  echo "FAIL: root URL returned ${HTTP_STATUS}"
  exit 2
fi

if grep -q -i "Welcome to nginx" /tmp/n8n_root.html; then
  echo "FAIL: still serving default Nginx page"
  exit 3
fi

if ! grep -q -Ei "n8n|n8n.io|N8N|Workflow|Sign in" /tmp/n8n_root.html; then
  echo "WARN: n8n markers not found in root response. Checking health endpoint."
fi

HEALTH_STATUS="$(curl -sk -o /tmp/n8n_health.json -w "%{http_code}" "https://${DOMAIN}/healthz")"
if [[ "${HEALTH_STATUS}" != "200" && "${HEALTH_STATUS}" != "301" ]]; then
  echo "FAIL: health endpoint returned ${HEALTH_STATUS}"
  exit 4
fi

if command -v jq >/dev/null 2>&1; then
  if jq -e . >/dev/null 2>&1 < /tmp/n8n_health.json; then
    echo "Health response JSON: $(cat /tmp/n8n_health.json | head -c 160)"
  fi
else
  echo "Health response body: $(cat /tmp/n8n_health.json | head -c 80)"
fi

echo "PASS: ${DOMAIN} responds to HTTPS and health endpoint"
exit 0
