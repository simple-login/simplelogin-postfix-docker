#!/usr/bin/env python3
"""Generate configuration files for SimpleLogin Postfix and Certbot.

Greatly inspired by:
https://aoeex.com/phile/postfix-dovecot-and-lets-encrypt-certificates/
"""

import os
import re
import sys
from os import environ
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined
from jinja2.exceptions import UndefinedError

# Certbot
CERTBOT_CONFIG_DIR = Path('/etc/letsencrypt')
CERTBOT_CONFIG_FILENAME = 'cli.ini'

# Let's Encrypt
LETSENCRYPT_CONFIG_DIR = CERTBOT_CONFIG_DIR / 'live'
LETSENCRYPT_CERTIFICATE = 'fullchain.pem'
LETSENCRYPT_PRIVATE_KEY = 'privkey.pem'

# Postfix
POSTFIX_CONFIG_DIR = Path('/etc/postfix')
POSTFIX_CONFIG_FILENAMES = ['main.cf', 'pgsql-relay-domains.cf', 'pgsql-transport-maps.cf', 'dnsbl-reply-map']  # noqa: E501

# Templates
TEMPLATES_DIR = Path('/src/templates')

templates = Environment(
    loader=FileSystemLoader(TEMPLATES_DIR),
    undefined=StrictUndefined,
    trim_blocks=True,  # To not show empty lines in place of block statements
)


def generate_certbot_config():
    """Generate Certbot's configuration file."""
    with (CERTBOT_CONFIG_DIR / CERTBOT_CONFIG_FILENAME).open('w') as f:
        template = templates.get_template(f'certbot/{CERTBOT_CONFIG_FILENAME}')
        f.write(template.render(env=environ))


def generate_postfix_config():
    """Generate Postfix's configuration files."""
    for filename in POSTFIX_CONFIG_FILENAMES:

        # If DQN KEY is provided
        if filename == 'dnsbl-reply-map' and environ.get('POSTFIX_DQN_KEY') is None:
            # skip generation of mapping file - not needed.
            continue

        filepath = POSTFIX_CONFIG_DIR / filename
        print(f"Generating Postfix configuration file: {filepath}")

        with (filepath).open('w') as config_file:
            template = templates.get_template(f'postfix/{filename}')

            cert_file = None
            key_file = None

            # Use custom certificate if provided or use Let's Encrypt certificate.
            if environ.get('TLS_KEY_FILE') is not None and environ.get('TLS_CERT_FILE') is not None:
                cert_file = Path(environ.get('TLS_CERT_FILE'))
                key_file = Path(environ.get('TLS_KEY_FILE'))

                print(f"|Using custom certificate:")
                print(f"|  with key file: {key_file}")
                print(f"|  with certificate file: {cert_file}")
            else:
                print("|Using Let's Encrypt certificate")
                ssl_cert_folder = environ.get('POSTFIX_FQDN')
                cert_file = LETSENCRYPT_CONFIG_DIR / ssl_cert_folder / LETSENCRYPT_CERTIFICATE
                key_file = LETSENCRYPT_CONFIG_DIR / ssl_cert_folder / LETSENCRYPT_PRIVATE_KEY
            
            # Check if certificate and key files exist. 
            enable_tls = cert_file.is_file() and key_file.is_file()

            if not enable_tls:
                print(f"|Certificate files are missing: {cert_file} and {key_file}")
            else:
                print("|Certificate files are present")            

            # Existing checks for creds didn't seem to work using {% if 'RELAY_HOST_USERNAME' in env and 'RELAY_HOST_PASSWORD' in env %} 
            # Generated main.cf didn't contain smtp_sasl_auth_enable = yes
            # Following three tests address RELAY config settings

            # Set up Relay Creds
            relay_creds_flag = (environ.get('RELAY_HOST_USERNAME') is not None and environ.get('RELAY_HOST_PASSWORD') is not None)

            # Set up Relay Host and Port
            relay_host_port_flag = (environ.get('RELAY_HOST') is not None and environ.get('RELAY_PORT') is not None)

            # Set up Relay Host Only
            relay_host_only_flag = (environ.get('RELAY_HOST') is not None and environ.get('RELAY_HOST_PASSWORD') is None)

            # Set up Use DQN
            use_dqn_flag = environ.get('POSTFIX_DQN_KEY') is not None

            # Enable Proxy Protocal if postfix is behind a reverse proxy that can use Proxy Protocol like trafik or haproxy.
            enable_proxy_protocol = os.getenv("ENABLE_PROXY_PROTOCOL", 'False').lower() in ('true', '1', 't')
            if enable_proxy_protocol:
                print(f"|Proxy Protocol is enabled.")
            else:
                print(f"|Proxy Protocol is disabled.")

            # Set up mynetworks
            use_mynetworks_flag = (environ.get('MYNETWORKS') is not None)

            # Generate config_file file.
            config_file.write(template.render(
                env=environ,
                tls=enable_tls,
                tls_cert=cert_file,
                tls_key=key_file,
                proxy_protocol=enable_proxy_protocol,
                relay_creds=relay_creds_flag,
                relay_host_only=relay_host_only_flag,
                relay_host_port=relay_host_port_flag,
                use_dqn=use_dqn_flag,
                use_mynetworks=use_mynetworks_flag,
            ))


def main():
    """Generate Certbot and/or Postfix's configuration files."""
    try:
        if '--certbot' in sys.argv or len(sys.argv) == 1:
            generate_certbot_config()

        if '--postfix' in sys.argv or len(sys.argv) == 1:
            generate_postfix_config()

    except (KeyError, UndefinedError) as exc:
        if isinstance(exc, KeyError):
            missing = exc.args[0]
        else:
            missing = re.match(r"'.+' .+ '(.+)'", exc.message)[1]

        print("Impossible to generate Postfix configuration files")
        sys.exit(f"You forgot to define the following environment variable: {missing}")


if __name__ == '__main__':
    main()
