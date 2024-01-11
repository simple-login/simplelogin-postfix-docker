# Docker Image for SimpleLogin Postfix

This project is a fork of [SimpleLogin/Postfix](https://github.com/simple-login/simplelogin-postfix-docker) with four key changes:
- Supports a port for SMTP relay (RELAY_PORT)
- Supports spamhaus Data Query Service
- Minor changes to config generation to work around issues noticed where RELAY_HOST and RELAY_HOST_USERNAME and RELAY_HOST_PASSWORD from config weren't generating appropriate entries in main.cf
- Handling PEP 668 Externally Managed which prevents Dockerfile build

Unless you need these features, you should be using https://github.com/simple-login/simplelogin-postfix-docker or the excellent https://github.com/springcomp/self-hosted-simplelogin which pulls it all together - I didn't as I had several other things already running which meant I needed to use different components.

No official Postfix image, tailor-made for [SimpleLogin](https://simplelogin.io/),
currently exists.

Let's fix that, by providing to the community something very lightweight,
secure\* (with [Let's Encrypt](https://letsencrypt.org/) support) and simple to use 💖

**Compatibility:** this image has been tested in a production environment with SimpleLogin **4.6.54 beta**

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
**RELAY_PORT** | SMTP Relay Host port.  Some relays require a specifc port (such as 587.
**RELAY_HOST_USERNAME** | SMTP Relay Host username.
**RELAY_HOST_PASSWORD** | SMTP Relay Host password. You can also use **RELAY_HOST_PASSWORD_FILE** if using with docker secrets.
**POSTFIX_DQN_KEY** | If you use a recursie DNS (or are on a cloud provider such as Oracle or Amazon that means you are on a recursive DNS, you can't use the zen.spamhaus.org standard rbl.  Sign up for a free DQN key [here](https://www.spamhaus.com/free-trial/sign-up-for-a-free-data-query-service-account/) and add this to your config.
**TLS_KEY_FILE** | Custom key file that provides custom TLS certificate. This **disables** Let's Encrypt. Useful if you use a reverse proxy which manages your certificates. If you are using Letsencrypt to get certificate, this file name would be: ``privkey.pem``.
**TLS_CERT_FILE** | Custom certificate file that provides custom TLS certificate. This **disables** Let's Encrypt. Useful if you use a reverse proxy which manages your certificates. If you are using Letsencrypt to get certificate, this file name would be: ``fullchain.pem``.
**SIMPLELOGIN_COMPATIBILITY_MODE** | Compatibility with Simplelogin major application version. The supported values are `v3` and `v4`. If not defined, it will default to `v3`.
**ENABLE_PROXY_PROTOCOL** | Enables [Proxy Protocal](https://www.haproxy.com/blog/efficient-smtp-relay-infrastructure-with-postfix-and-load-balancers/) if postfix is behind a reverse proxy that can use Proxy Protocol like `trafik` or `haproxy`. The default value is `false`. *Note: You must also enable this in your reverse to use this feature.*

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
