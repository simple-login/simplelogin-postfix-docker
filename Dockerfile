FROM alpine:3

EXPOSE 25 465
VOLUME /etc/letsencrypt

# Install system dependencies.
RUN apk add --update --no-cache \
    # Postfix itself:
    postfix>=3.6 postfix-pgsql>=3.6 \
    # To generate Postfix config files:
    python3>=3.10 \
    # To generate and renew Postfix TLS certificate:
    certbot>=1.29.0 \
    dcron>=4.5 \
    bash

# Install Python dependencies.
RUN python3 -m ensurepip && pip3 install jinja2==3.1.2

# Copy sources.
COPY generate_config.py /src/
COPY scripts/certbot-renew-crontab.sh /etc/periodic/hourly/renew-postfix-tls
COPY scripts/certbot-renew-posthook.sh /etc/letsencrypt/renewal-hooks/post/reload-postfix.sh
COPY templates /src/templates
COPY entrypoint.sh /src/docker-entrypoint.sh

# Generate config, ask for a TLS certificate to Let's Encrypt, start Postfix and Cron daemon.
WORKDIR /src
CMD ["./docker-entrypoint.sh"]

