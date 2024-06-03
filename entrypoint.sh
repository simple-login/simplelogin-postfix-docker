#!/usr/bin/env bash

# Supported compatibility modes for Simplelogin
readonly VALID_COMPATIBILITY_MODES=("v3" "v4")

# POstfix Custom Data Directory
readonly DEFAULT_POSTFIX_CUSTOM_DATA_DIRECTORY="/etc/postfix/custom-data"

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

setup_postfix_custom_data () {
  if  [[ ! "${POSTFIX_CUSTOM_DATA_DIRECTORY}" ]]; then
    export POSTFIX_CUSTOM_DATA_DIRECTORY="${DEFAULT_POSTFIX_CUSTOM_DATA_DIRECTORY}";
  fi

  mkdir -p ${POSTFIX_CUSTOM_DATA_DIRECTORY}

  if [[ ! -f ${POSTFIX_CUSTOM_DATA_DIRECTORY}/aliases ]]; then
    touch ${POSTFIX_CUSTOM_DATA_DIRECTORY}/aliases
    postalias ${POSTFIX_CUSTOM_DATA_DIRECTORY}/aliases
  fi
}

setup_dnsbl_reply_map () {
  if  [[ "${POSTFIX_DQN_KEY}" ]]; then
    postmap lmdb:/etc/postfix/dnsbl-reply-map
  fi
}

_main() {
  # Each environment variable that supports the *_FILE pattern needs to be passed into the file_env() function.
  file_env "DB_PASSWORD"
  file_env "RELAY_HOST_PASSWORD"

  setup_postfix_custom_data


  # Test if SIMPLELOGIN_COMPATIBILITY_MODE option was not present, and set it to default v3.
  if  [[ ! "${SIMPLELOGIN_COMPATIBILITY_MODE}" ]] ; then
    export SIMPLELOGIN_COMPATIBILITY_MODE="v3";
  else
    # Test that SIMPLELOGIN_COMPATIBILITY_MODE contains a valid value
    if ! contains_element "${SIMPLELOGIN_COMPATIBILITY_MODE}" "${VALID_COMPATIBILITY_MODES[@]}"; then
      echo "Simplelogin Compatibility Mode: ${SIMPLELOGIN_COMPATIBILITY_MODE} is not valid! Valid values are: (${VALID_COMPATIBILITY_MODES[*]})"
      exit -1
    else
      echo "Simplelogin Compatibility Mode is set to: ${SIMPLELOGIN_COMPATIBILITY_MODE}"
    fi
  fi

  if [[ -f ${TLS_KEY_FILE} && -f ${TLS_CERT_FILE}  ]]; then
    python3 generate_config.py --postfix && setup_dnsbl_reply_map && postfix start-fg
  else
    python3 generate_config.py --certbot && certbot -n certonly; crond && python3 generate_config.py --postfix && setup_dnsbl_reply_map && postfix start-fg
  fi
}

_main "$@"
