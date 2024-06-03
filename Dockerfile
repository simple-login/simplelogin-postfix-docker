FROM alpine:3

ARG CERTBOT_VERSION=2.10.0
ARG PYTHON_VERSION=3.12
ARG POSTFIX_VERSION=3.9.0
ARG DCRON_VERSION=4.5

# set version label
ARG BUILD_DATE
ARG VERSION

LABEL build_version="simplelogin-postfix version:- ${VERSION} Build-date:- ${BUILD_DATE}"

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
    dcron>=${DCRON_VERSION} \
    # Install Python dependencies:
    py3-jinja2 \
    # Install bash:
    bash

# Copy sources.
COPY generate_config.py /src/
COPY scripts/certbot-renew-crontab.sh /etc/periodic/hourly/renew-postfix-tls
COPY scripts/certbot-renew-posthook.sh /etc/letsencrypt/renewal-hooks/post/reload-postfix.sh
COPY templates /src/templates
COPY entrypoint.sh /src/docker-entrypoint.sh

# Generate config, ask for a TLS certificate to Let's Encrypt, start Postfix and Cron daemon.
WORKDIR /src

  # Idea taken from https://github.com/Mailu/Mailu/blob/master/core/postfix/Dockerfile
HEALTHCHECK --start-period=350s CMD /usr/sbin/postfix status

CMD ["./docker-entrypoint.sh"]

