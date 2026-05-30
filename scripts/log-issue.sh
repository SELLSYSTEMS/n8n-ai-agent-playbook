#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: ./scripts/log-issue.sh \"summary of issue + fix\""
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/../notes/installation-log.md"
TIMESTAMP="$(date -Iseconds)"

{
  echo
  echo "### ${TIMESTAMP}"
  echo "- $*"
} >> "${LOG_FILE}"

echo "Logged to ${LOG_FILE}"
