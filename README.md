# Docker Image for SimpleLogin Postfix with certbot dns01 challenge

This is a Postfix Docker image with Certbot builtin. It supports both Certbot `http-01` and automatic `dns-01` Challenge types. For `dns-01`, 
currently the following plugins are supported:

Certbot Plugin | Documentation
-------------- | -------------------------------------------
Cloudflare     | [cloudflare dns plugin](https://certbot-dns-cloudflare.readthedocs.io/en/stable/#)
Linode         | [linode dns plugin](https://certbot-dns-linode.readthedocs.io/en/stable/#)

Hopefully this list will grow over time.

**Compatibility:** this image has been tested in a production environment with SimpleLogin **3.4.0**

\* if a TLS certificate cannot be automatically generated when starting the container, Postfix will run without TLS activated, until the next attempt (happens every hour)

This container can be configured with the following environment variables:

Setting | Description
------- | -------------------------------------------
**ALIASES_DEFAULT_DOMAIN** | Default domain to use for your aliases.
**DB_HOST** | Where is hosted your SimpleLogin PostgreSQL database.
**DB_USER** | User to connect to the database.
**DB_PASSWORD** | User's password to connect to the database. You can also use **DB_PASSWORD_FILE** if using with docker secrets.
**DB_NAME** | Name of the database.
**EMAIL_HANDLER_HOST** | Where is hosted your SimpleLogin email handler instance.
**POSTFIX_FQDN** | Fully Qualified Domain Name of your Postfix instance (i.e., the MX server address you configured in your DNS zone for your **ALIASES_DEFAULT_DOMAIN**).
**RELAY_HOST** | If your Postfix instance's IP address is blacklisted (e.g., because it is not a static address), you must use your Internet Service Provider's mail server as a relay, to be able to send emails to the outer world.
**SSL_CERT_FOLDER** | Custom folder location for storing your own SSL certificate. This **disables** Let's Encrypt. Useful if you use a reverse proxy which manages your certificates. The certificate file name should be: ``fullchain.pem`` and the private key's file name should be: ``privkey.pem``.
**LETSENCRYPT_AUTHENTICATOR** | The authentication challenge and plugin types. Must be be one of these: <ul><li>standalone</li><li>cloudflare</li><li>linode</li></ul>
**LETSENCRYPT_USE_STAGING** | Make certbot use the staging ACME servers. This will allow you to test your configuration. The values can be `true` or `false`.
**LETSENCRYPT_DNS_KEY** | API key used for `dns-01` authentication challenge. You can also use **LETSENCRYPT_DNS_KEY_FILE** if using with docker secrets.
**LETSENCRYPT_EMAIL** | Email address used by Let's Encrypt, to send you expiry notices\*.

\* automatic renewal is managed with [Certbot](https://certbot.eff.org/) and shouldn't fail, unless you have reached Let's Encrypt [rate limits](https://letsencrypt.org/docs/rate-limits/)

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
