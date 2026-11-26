# AGENTS.md

Docker image that runs Postfix for SimpleLogin. No application code: the image entrypoint renders config from Jinja2 templates, optionally obtains a Let's Encrypt cert, then runs Postfix in the foreground.

## Commands

- Build: `docker build -t simplelogin/postfix .`
- Smoke test (de facto integration test, no unit tests): `tests/run-compose-test.sh examples/external-db-password-file/docker-compose.yml sut`
  - The `sut` service succeeds only when Postfix answers on port 25 with an ESMTP banner.
- Custom TLS smoke test: `tests/run-compose-test.sh examples/external-tls-certs/docker-compose.yml sut`
  - Waits for `certgen` and verifies STARTTLS returns a certificate.
- Proxy smoke test: `tests/run-compose-test.sh examples/proxy-protocol/docker-compose.yml sut`
  - Verifies Traefik -> Postfix PROXY v2 on `10025`, direct `25`, and open-relay rejection from the untrusted `proxy-net`.
  - Starts a minimal Postgres service (`examples/proxy-protocol/init.sql`) so the relay rejection is evaluated against a working `relay_domains` lookup.
- Dockerfile lint: `hadolint Dockerfile` (`.hadolint.yaml` ignores DL3018 because apk packages are intentionally unpinned).
- Shell lint: `shellcheck entrypoint.sh scripts/*.sh tests/*.sh`
- Python syntax check: `python3 -m py_compile generate_config.py` (only stdlib + `py3-jinja2`, installed in the image).
- Compose validation: `docker compose -f examples/<name>/docker-compose.yml config`

`tests/run-compose-test.sh` uses `docker compose wait`, so it requires Compose v2.17 or newer.

CI (`.github/workflows/main.yml`) runs lint and the compose smoke tests before building/pushing the multi-arch image.

## Config generation

- `entrypoint.sh` -> `generate_config.py` -> templates in `templates/`. Generated files (`/etc/postfix/*`, `/etc/letsencrypt/cli.ini`) are not in the repo; edit the templates.
- Paths in `generate_config.py` are absolute (`/src/templates`, `/etc/postfix`, `/etc/letsencrypt`), so it only works inside the image or with those paths present.
- Jinja2 uses `StrictUndefined`: a missing env var aborts generation. `POSTFIX_CUSTOM_DATA_DIRECTORY` (default `/etc/postfix/custom-data`) is exported by the entrypoint, so set it manually when running `generate_config.py --postfix` directly.
- `--certbot` / `--postfix` select parts; no args renders both.
- `dnsbl-reply-map` is generated only when `POSTFIX_DQN_KEY` is set; it must then be indexed with `postmap lmdb:/etc/postfix/dnsbl-reply-map` (entrypoint does this).
- `SIMPLELOGIN_COMPATIBILITY_MODE` defaults to `v3`. `v4` additionally queries the `public_domain` table in `pgsql-relay-domains.cf` and `pgsql-transport-maps.cf`; keep both mode branches in sync.

## Gotchas

- `templates/postfix/main.cf` contains the security rules. `smtpd_relay_restrictions` ordering is deliberate (recent commits fixed an open-relay regression); do not reorder it casually.
- `compatibility_level` is `3.11` and must stay in sync with `POSTFIX_VERSION` (currently `3.11`). `smtp_tlsrpt_skip_reused_handshakes` is intentionally left unset so Postfix 3.11's new default applies.
- `ENABLE_PROXY_PROTOCOL` must only affect the dedicated `POSTFIX_PROXY_PROTOCOL_PORT` listener (default `10025`), created with `postconf -M`/`-P` in `entrypoint.sh`. Never set `smtpd_upstream_proxy_protocol` globally in `main.cf`; `:25` must stay non-PROXY for SimpleLogin.
- Custom TLS (`TLS_KEY_FILE` + `TLS_CERT_FILE` both set) skips Certbot entirely. Otherwise Certbot uses `standalone` for `POSTFIX_FQDN`; renewal is hourly via `/etc/periodic/hourly/renew-postfix-tls`, and the post-hook regenerates Postfix config and reloads. Certbot startup is slow; the healthcheck has a 350s start period.
- `DB_PASSWORD` and `RELAY_HOST_PASSWORD` support Docker-secret `*_FILE` variants, resolved in `entrypoint.sh` (`file_env`).
- Dockerfile version `ARG`s (`CERTBOT_VERSION`, `PYTHON_VERSION`, `POSTFIX_VERSION`, `DCRON_VERSION`) are the place to bump dependency versions.
- `README.md`'s env-var table is the user-facing reference; update it when adding an env var.

## Workflow

- Feature work goes on `develop/*` branches merged into `master` via PR; releases are `vX.Y.Z` tags (CI derives semver tags from them).
