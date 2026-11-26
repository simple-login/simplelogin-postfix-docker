#!/usr/bin/env bash

set -euo pipefail

# Supported compatibility modes for Simplelogin
readonly VALID_COMPATIBILITY_MODES=("v3" "v4")

# POstfix Custom Data Directory
readonly DEFAULT_POSTFIX_CUSTOM_DATA_DIRECTORY="/etc/postfix/custom-data"

readonly DEFAULT_POSTFIX_PROXY_PROTOCOL_PORT="10025"

# This function reads the docker secrets based variables defined with pattern *_FILE into the normal variables
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'DB_PASSWORD' 'default_password'
# (will allow for "$DB_PASSWORD_FILE" to fill in the value of
#  "$DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [[ -n "${!var:-}" && -n "${!fileVar:-}" ]]; then
    echo "Both $var and $fileVar are set (but are exclusive)" >&2
    exit 1
  fi
  local val="$def"
  if [[ -n "${!var:-}" ]]; then
    val="${!var}"
  elif [[ -n "${!fileVar:-}" ]]; then
    if [[ ! -r "${!fileVar}" ]]; then
      echo "Cannot read $fileVar: ${!fileVar}" >&2
      exit 1
    fi
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

# A simple utility function to check if a given value is present in array
# The first argument is the value to be checked
# The second argument is a bash array
# Example:
# readonly MODES=("up" "down")
# local current_mode="up"
# if ! contains_element "${current_mode}" "${MODES[@]}"; then
#   echo "Current mode is not valid value ${current_mode}"
#   echo "Valid values are: (${MODES[*]})"
#   exit -1
# else
#   echo "Found value: ${current_mode}"
# fi
contains_element () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

validate_custom_tls () {
  local key="${TLS_KEY_FILE:-}"
  local cert="${TLS_CERT_FILE:-}"

  if [[ -n "$key" && -z "$cert" ]] || [[ -z "$key" && -n "$cert" ]]; then
    echo "TLS_KEY_FILE and TLS_CERT_FILE must be set together." >&2
    exit 1
  fi

  if [[ -n "$key" ]]; then
    if [[ ! -f "$key" || ! -r "$key" ]]; then
      echo "TLS_KEY_FILE is not a readable file: $key" >&2
      exit 1
    fi
    if [[ ! -f "$cert" || ! -r "$cert" ]]; then
      echo "TLS_CERT_FILE is not a readable file: $cert" >&2
      exit 1
    fi
  fi
}

setup_postfix_custom_data () {
  if [[ -z "${POSTFIX_CUSTOM_DATA_DIRECTORY:-}" ]]; then
    export POSTFIX_CUSTOM_DATA_DIRECTORY="${DEFAULT_POSTFIX_CUSTOM_DATA_DIRECTORY}"
  fi

  mkdir -p "${POSTFIX_CUSTOM_DATA_DIRECTORY}"

  if [[ ! -f "${POSTFIX_CUSTOM_DATA_DIRECTORY}/aliases" ]]; then
    touch "${POSTFIX_CUSTOM_DATA_DIRECTORY}/aliases"
    postalias "${POSTFIX_CUSTOM_DATA_DIRECTORY}/aliases"
  fi
}

setup_dnsbl_reply_map () {
  if [[ -n "${POSTFIX_DQN_KEY:-}" ]]; then
    postmap lmdb:/etc/postfix/dnsbl-reply-map
  fi
}

setup_proxy_protocol () {
  local port="${POSTFIX_PROXY_PROTOCOL_PORT:-${DEFAULT_POSTFIX_PROXY_PROTOCOL_PORT}}"
  local proxy_protocol="${ENABLE_PROXY_PROTOCOL:-}"

  if [[ "${proxy_protocol,,}" =~ ^(true|1|t)$ ]]; then
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || (( 10#${port} < 1 || 10#${port} > 65535 )); then
      echo "Invalid POSTFIX_PROXY_PROTOCOL_PORT: ${port}" >&2
      exit 1
    fi

    if (( 10#${port} == 25 )); then
      echo "POSTFIX_PROXY_PROTOCOL_PORT cannot be 25; port 25 must remain non-PROXY for SimpleLogin." >&2
      exit 1
    fi

    postconf -M "${port}/inet=${port} inet n - n - - smtpd"
    postconf -P "${port}/inet/smtpd_upstream_proxy_protocol=haproxy"
  elif [[ "${port}" =~ ^[0-9]+$ ]] && (( 10#${port} >= 1 && 10#${port} <= 65535 )) && (( 10#${port} != 25 )); then
    postconf -MX "${port}/inet" 2>/dev/null || true
  fi
}

_main() {
  # Each environment variable that supports the *_FILE pattern needs to be passed into the file_env() function.
  file_env "DB_PASSWORD"
  file_env "RELAY_HOST_PASSWORD"

  validate_custom_tls
  setup_postfix_custom_data

  # Test if SIMPLELOGIN_COMPATIBILITY_MODE option was not present, and set it to default v3.
  if [[ -z "${SIMPLELOGIN_COMPATIBILITY_MODE:-}" ]]; then
    export SIMPLELOGIN_COMPATIBILITY_MODE="v3"
  elif ! contains_element "${SIMPLELOGIN_COMPATIBILITY_MODE}" "${VALID_COMPATIBILITY_MODES[@]}"; then
    echo "Simplelogin Compatibility Mode: ${SIMPLELOGIN_COMPATIBILITY_MODE} is not valid! Valid values are: (${VALID_COMPATIBILITY_MODES[*]})" >&2
    exit 1
  else
    echo "Simplelogin Compatibility Mode is set to: ${SIMPLELOGIN_COMPATIBILITY_MODE}"
  fi

  if [[ -n "${TLS_KEY_FILE:-}" ]]; then
    python3 generate_config.py --postfix
    setup_dnsbl_reply_map
    setup_proxy_protocol
    exec postfix start-fg
  fi

  rm -f /etc/letsencrypt/renewal-hooks/post/reload-postfix.sh 2>/dev/null || true
  python3 generate_config.py --certbot
  if ! certbot -n certonly; then
    echo "Certbot failed; starting Postfix without TLS until the next renewal attempt." >&2
  fi
  crond
  python3 generate_config.py --postfix
  setup_dnsbl_reply_map
  setup_proxy_protocol
  exec postfix start-fg
}

_main "$@"
