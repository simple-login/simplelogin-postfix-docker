#!/usr/bin/env bash

# This function reads the docker secrets based variables defined with pattern *_FILE into the normal variables
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'DB_PASSWORD' 'default_password'
# (will allow for "$DB_PASSWORD_FILE" to fill in the value of
#  "$DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
  	echo "Both $var and $fileVar are set (but are exclusive)"
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
  	val="${!var}"
  elif [ "${!fileVar:-}" ]; then
  	val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

_main() {
  # Each environment variable that supports the *_FILE pattern eeds to be passed into the file_env() function.
  file_env "DB_PASSWORD"
  file_env "LETSENCRYPT_DNS_KEY"

  if [ -d ${SSL_CERT_FOLDER} ]; then
    crond && python3 generate_config.py --postfix && postfix start-fg
  else
    if [ "${LETSENCRYPT_USE_STAGING}" == "true" ]; then
      echo "Using certbot in staging mode."
    fi

    python3 generate_config.py --certbot && certbot -n certonly; crond && python3 generate_config.py --postfix && postfix start-fg
  fi

  # Idea taken from https://github.com/Mailu/Mailu/blob/master/core/postfix/Dockerfile
  HEALTHCHECK --start-period=350s CMD echo QUIT|nc localhost 25|grep "220 .* ESMTP Postfix"
}

_main "$@"
