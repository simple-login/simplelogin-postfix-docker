#!/usr/bin/env bash

set -e

CERTIFICATE="/etc/letsencrypt/live/$POSTFIX_FQDN/fullchain.pem"
PRIVATE_KEY="/etc/letsencrypt/live/$POSTFIX_FQDN/privkey.pem"

if [ "${LETSENCRYPT_USE_STAGING}" == "true" ]; then
  echo "Using certbot in staging mode."
fi

if [ -f ${CERTIFICATE} -a -f ${PRIVATE_KEY} ]; then
    certbot -q renew
else
    certbot -q certonly
fi
