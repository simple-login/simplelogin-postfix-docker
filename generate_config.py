#!/usr/bin/env python3
"""Generate configuration files for SimpleLogin Postfix and Certbot.

Greatly inspired by:
https://aoeex.com/phile/postfix-dovecot-and-lets-encrypt-certificates/
"""

import re
import sys
from os import environ
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined
from jinja2.exceptions import UndefinedError

# Certbot
CERTBOT_CONFIG_DIR = Path('/etc/letsencrypt')
CERTBOT_CONFIG_FILENAME = 'cli.ini'
CERTBOT_DNS_CREDS_DIR = Path('/credentials')
CERTBOT_DNS_CREDS_FILENAME = 'dns-creds.ini'

# Let's Encrypt
LETSENCRYPT_CONFIG_DIR = CERTBOT_CONFIG_DIR / 'live'
LETSENCRYPT_CERTIFICATE = 'fullchain.pem'
LETSENCRYPT_PRIVATE_KEY = 'privkey.pem'

# Postfix
POSTFIX_CONFIG_DIR = Path('/etc/postfix')
POSTFIX_CONFIG_FILENAMES = ['main.cf', 'pgsql-relay-domains.cf', 'pgsql-transport-maps.cf']  # noqa: E501

# Templates
TEMPLATES_DIR = Path('/src/templates')

templates = Environment(
    loader=FileSystemLoader(TEMPLATES_DIR),
    undefined=StrictUndefined,
    trim_blocks=True,  # To not show empty lines in place of block statements
)


def generate_certbot_config():
    # Check the selected Authenticator.
    active_authenticator = environ['LETSENCRYPT_AUTHENTICATOR']

    print(f"""Generate Certbot's configuration file using {active_authenticator}.""")
    with (CERTBOT_CONFIG_DIR / CERTBOT_CONFIG_FILENAME).open('w') as f:
        cli_template = templates.get_template(f'certbot/{CERTBOT_CONFIG_FILENAME}')

        f.write(cli_template.render(
            env=environ,
        ))

    print(f"""Generate Certbot's DNS credentials file using {active_authenticator}.""")
    with (CERTBOT_DNS_CREDS_DIR / CERTBOT_DNS_CREDS_FILENAME).open('w') as f:
        creds_template = templates.get_template(f'certbot/credentials/{CERTBOT_DNS_CREDS_FILENAME}')

        f.write(creds_template.render(
            env=environ,
        ))


def generate_postfix_config():
    """Generate Postfix's configuration files."""
    for config in POSTFIX_CONFIG_FILENAMES:
        with (POSTFIX_CONFIG_DIR / config).open('w') as f:
            template = templates.get_template(f'postfix/{config}')

            cert_file = None
            key_file = None

            # Use custom certificate if provided or use Let's Encrypt certificate.
            if environ.get('SSL_CERT_FOLDER') is not None:
                print(f"Using custom certificate: {environ.get('SSL_CERT_FOLDER')}")
                cert_file = Path(environ.get('SSL_CERT_FOLDER')) / LETSENCRYPT_CERTIFICATE
                key_file = Path(environ.get('SSL_CERT_FOLDER')) / LETSENCRYPT_PRIVATE_KEY
            else:
                print("Using Let's Encrypt certificate")
                ssl_cert_folder = environ.get('POSTFIX_FQDN')
                cert_file = LETSENCRYPT_CONFIG_DIR / ssl_cert_folder / LETSENCRYPT_CERTIFICATE
                key_file = LETSENCRYPT_CONFIG_DIR / ssl_cert_folder / LETSENCRYPT_PRIVATE_KEY
            
            # Check if certificate and key files exist. 
            enable_tls = cert_file.is_file() and key_file.is_file()
            

            if not enable_tls:
                print(f"Certificate files are missing: {cert_file} and {key_file}")
            else:
                print("Certificate files are present")            

            # Generate config file.
            f.write(template.render(
                env=environ,
                tls=enable_tls,
                tls_cert=cert_file,
                tls_key=key_file,
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
