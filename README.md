# Docker Image for SimpleLogin Postfix

No official Postfix image, tailor-made for [SimpleLogin](https://simplelogin.io/),
currently exists.

Let's fix that, by providing to the community something very lightweight,
secure\* (with [Let's Encrypt](https://letsencrypt.org/) support) and simple to use 💖

**Compatibility:** this image has been tested in a production environment with SimpleLogin **3.4.0**

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
**RELAY_HOST** | If your Postfix instance's IP address is blacklisted (e.g., because it is not a static address), you must use your Internet Service Provider's mail server as a relay, to be able to send emails to the outer world. If RELAY_HOST_USERNAME and RELAY_HOST_PASSWORD specified in Docker Run / Compose, it will enable authentication to SMTP relay host.
**SSL_CERT_FOLDER** | Custom folder location for storing your own SSL certificate. This **disables** Let's Encrypt. Useful if you use a reverse proxy which manages your certificates. The certificate file name should be: ``fullchain.pem`` and the private key's file name should be: ``privkey.pem``.
**SIMPLELOGIN_COMPATIBILITY_MODE** | Compatibility with Simplelogin major application version. The supported values are `v3` and `v4`. If not defined, it will default to `v3`.

\* automatic renewal is managed with [Certbot](https://certbot.eff.org/) and shouldn't fail, unless you have reached Let's Encrypt [rate limits](https://letsencrypt.org/docs/rate-limits/)

Used by and made for [Kloügle](https://github.com/arugifa/klougle), the Google
alternative automated with [Terraform](https://www.terraform.io/).

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
