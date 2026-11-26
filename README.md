# Docker Image for SimpleLogin Postfix

No official Postfix image, tailor-made for [SimpleLogin](https://simplelogin.io/),
currently exists.

Let's fix that, by providing to the community something very lightweight,
secure\* (with [Let's Encrypt](https://letsencrypt.org/) support) and simple to use 💖

**Compatibility:** this image supports SimpleLogin **v3** and **v4** compatibility modes.

\* if a TLS certificate cannot be automatically generated when starting the container, Postfix will run without TLS activated, until the next attempt (happens every hour)

Can be configured with the following environment variables:

Setting     | Description
----------- | -------------------------------------------
**ALIASES_DEFAULT_DOMAIN** | Default domain to use for your aliases.
**DB_HOST** | Where is hosted your SimpleLogin PostgreSQL database.
**DB_USER** | User to connect to the database.
**DB_PASSWORD** | User's password to connect to the database. You can also use **DB_PASSWORD_FILE** if using with docker secrets.
**DB_NAME** | Name of the database.
**EMAIL_HANDLER_HOST** | Where is hosted your SimpleLogin email handler instance.
**LETSENCRYPT_EMAIL** | Email address used by Let's Encrypt, to send you expiry notices\*.
**POSTFIX_FQDN** | Fully Qualified Domain Name of your Postfix instance (i.e., the MX server address you configured in your DNS zone for your **ALIASES_DEFAULT_DOMAIN**).
**RELAY_HOST** | If your Postfix instance's IP address is blacklisted (e.g., because it is not a static address), you must use your Internet Service Provider's mail server as a relay, to be able to send emails to the outer world. If **RELAY_HOST_USERNAME** and **RELAY_HOST_PASSWORD** specified in Docker Run / Compose, it will enable authentication to SMTP relay host.
**RELAY_PORT** | SMTP Relay Host port. Some relays require a specific port (such as 587).
**RELAY_HOST_USERNAME** | SMTP Relay Host username.
**RELAY_HOST_PASSWORD** | SMTP Relay Host password. You can also use **RELAY_HOST_PASSWORD_FILE** if using with docker secrets.
**POSTFIX_DQN_KEY** | If you use a recursive DNS (or are on a cloud provider such as Oracle or Amazon that means you are on a recursive DNS), you can't use the zen.spamhaus.org standard rbl.  Sign up for a free DQN key [here](https://www.spamhaus.com/free-trial/sign-up-for-a-free-data-query-service-account/) and add this to your config.
**TLS_KEY_FILE** | Custom TLS private key file. Requires **TLS_CERT_FILE** and **disables** Let's Encrypt. Useful if you use a reverse proxy which manages your certificates.
**TLS_CERT_FILE** | Custom TLS certificate chain file. Requires **TLS_KEY_FILE** and **disables** Let's Encrypt. Useful if you use a reverse proxy which manages your certificates.
**SIMPLELOGIN_COMPATIBILITY_MODE** | Compatibility with Simplelogin major application version. The supported values are `v3` and `v4`. If not defined, it will default to `v3`.
**ENABLE_PROXY_PROTOCOL** | Enables a dedicated [Proxy Protocol](https://www.haproxy.com/blog/efficient-smtp-relay-infrastructure-with-postfix-and-load-balancers/) listener for reverse proxies such as Traefik or HAProxy. The default value is `false`. Port `25` remains a normal SMTP listener and is not affected. *Note: You must also enable Proxy Protocol in your reverse proxy.*
**POSTFIX_PROXY_PROTOCOL_PORT** | Port for the Proxy Protocol listener when **ENABLE_PROXY_PROTOCOL** is enabled. Defaults to `10025`. Must not be `25`, and should not be published publicly.
**MYNETWORKS** | Authorized networks (CIDR format) from which Postfix will forward mail. If unset, Postfix trusts the whole Docker subnet (`mynetworks_style = subnet`); set this explicitly when other containers share the network.

When upgrading from an image where **ENABLE_PROXY_PROTOCOL** affected port `25`, point your reverse proxy at **POSTFIX_PROXY_PROTOCOL_PORT** (default `10025`) and keep SimpleLogin pointed at `postfix:25`.

## Operational notes

- **Ports:** Postfix listens on `25` (SMTP) and optionally `10025` (Proxy Protocol). Port `80` is used only during Certbot standalone validation. Port `465` is not configured.
- **Certbot standalone:** Let's Encrypt HTTP-01 validation requires **POSTFIX_FQDN** to resolve to the host and port `80/tcp` to be reachable from the internet. Publish port 80, or use custom TLS files.
- **Custom TLS:** **TLS_KEY_FILE** and **TLS_CERT_FILE** must both be set and readable at startup; otherwise the container exits instead of silently running without TLS.
- **Proxy Protocol port changes:** recreate the container when changing **POSTFIX_PROXY_PROTOCOL_PORT**; a restart can leave the previous listener in `master.cf`.
- **Mail queue persistence:** mount `/var/spool/postfix` and `/var/lib/postfix` if queued mail must survive container recreation.

\* automatic renewal is managed with [Certbot](https://certbot.eff.org/) and shouldn't fail, unless you have reached Let's Encrypt [rate limits](https://letsencrypt.org/docs/rate-limits/)

**NOTE**: This project is a fork of [Kloügle](https://github.com/arugifa/klougle).

## Examples

There are some example compose files in `examples` that show how to use this container in different scenarios.

## Troubleshooting

If you don't receive emails from SimpleLogin, have a look to Postfix logs:
```sh
docker logs -f <POSTFIX_CONTAINER>
```

If Postfix doesn't seem to use TLS, have a look to Certbot logs:
```sh
docker exec -ti <POSTFIX_CONTAINER> cat /var/log/letsencrypt/letsencrypt.log
```
