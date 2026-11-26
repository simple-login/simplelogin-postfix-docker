#!/usr/bin/env bash

set -euo pipefail

export POSTFIX_CUSTOM_DATA_DIRECTORY="${POSTFIX_CUSTOM_DATA_DIRECTORY:-/etc/postfix/custom-data}"

python3 /src/generate_config.py --postfix

if postfix status >/dev/null 2>&1; then
  postfix reload
fi
