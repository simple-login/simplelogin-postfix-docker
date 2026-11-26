#!/usr/bin/env bash

set -euo pipefail

: "${POSTFIX_FQDN:?POSTFIX_FQDN must be set}"

CERTIFICATE="/etc/letsencrypt/live/${POSTFIX_FQDN}/fullchain.pem"
PRIVATE_KEY="/etc/letsencrypt/live/${POSTFIX_FQDN}/privkey.pem"
DEPLOY_HOOK="/usr/local/bin/reload-postfix"

if [[ -f "${CERTIFICATE}" && -f "${PRIVATE_KEY}" ]]; then
  certbot -q renew --non-interactive --deploy-hook "${DEPLOY_HOOK}"
else
  certbot -q certonly --non-interactive --deploy-hook "${DEPLOY_HOOK}"
fi
