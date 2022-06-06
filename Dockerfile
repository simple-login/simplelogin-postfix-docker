FROM alpine:3

EXPOSE 25 465
VOLUME /etc/letsencrypt

# Install system dependencies.
RUN apk add --update --no-cache \
    # Postfix itself:
    postfix>=3.5 postfix-pgsql>=3.5 \
    # To generate Postfix config files:
    python3>=3.8 \
    # To generate and renew Postfix TLS certificate:
    certbot>=1.20 \
    dcron>=4.5 \
    bash

# Install Python dependencies.
RUN python3 -m ensurepip && pip3 install jinja2==2.11.3 MarkupSafe==2.0.1

# Copy sources.
COPY generate_config.py /src/
COPY scripts/certbot-renew-crontab.sh /etc/periodic/hourly/renew-postfix-tls
COPY scripts/certbot-renew-posthook.sh /etc/letsencrypt/renewal-hooks/post/reload-postfix.sh
COPY templates /src/templates
COPY entrypoint.sh /src/docker-entrypoint.sh

# Generate config, ask for a TLS certificate to Let's Encrypt, start Postfix and Cron daemon.
WORKDIR /src
CMD ["./docker-entrypoint.sh"]

