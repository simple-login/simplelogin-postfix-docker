FROM alpine:3

ARG CERTBOT_VERSION=2.2.0
ARG PYTHON_VERSION=3.10
ARG JINJA_VERSION=3.1.2
ARG POSTFIX_VERSION=3.7.4

# set version label
ARG BUILD_DATE
ARG VERSION

LABEL build_version="auto-cert-manager version:- ${VERSION} Build-date:- ${BUILD_DATE}"

EXPOSE 25 465
VOLUME /etc/letsencrypt

# Install system dependencies.
RUN apk add --update --no-cache \
    # Postfix itself:
    postfix>=${POSTFIX_VERSION} postfix-pgsql>=${POSTFIX_VERSION} \
    # To generate Postfix config files:
    python3>=${PYTHON_VERSION} \
    # To generate and renew Postfix TLS certificate:
    certbot>=${CERTBOT_VERSION} \
    dcron>=4.5 \
    bash

# Install Python dependencies.
RUN python3 -m ensurepip && pip3 install jinja2==${JINJA_VERSION}

# Copy sources.
COPY generate_config.py /src/
COPY scripts/certbot-renew-crontab.sh /etc/periodic/hourly/renew-postfix-tls
COPY scripts/certbot-renew-posthook.sh /etc/letsencrypt/renewal-hooks/post/reload-postfix.sh
COPY templates /src/templates
COPY entrypoint.sh /src/docker-entrypoint.sh

# Generate config, ask for a TLS certificate to Let's Encrypt, start Postfix and Cron daemon.
WORKDIR /src
CMD ["./docker-entrypoint.sh"]

