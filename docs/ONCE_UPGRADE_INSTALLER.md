# One-Click Installer / Upgrade from once

This repo includes `script/install-or-upgrade-from-once` to migrate safely from an
existing once-managed Campfire container to this fork.

It is designed to avoid downtime and protect existing production data:

1. Detect existing `campfire` container.
2. Back up container metadata and `/rails/storage`.
3. Create `.env.production` from `.env.production.example`.
4. Prefill env values from the existing container (`SECRET_KEY_BASE`, SSL, VAPID, etc).
5. Fix ownership/permissions of migrated storage for non-root app user.
6. Validate storage write access before deploy.
7. Start a canary deployment on `8080/8443` (or skip if ports are occupied).
8. Print explicit cutover and rollback commands.

## Run directly on server (curl style)

```bash
curl -fsSL https://raw.githubusercontent.com/Jalappeno-apps/once-campfire/main/script/install-or-upgrade-from-once | bash
```

## Useful environment overrides

```bash
INSTALL_DIR=/opt/once-campfire
APP_DIR=/opt/once-campfire/app
REPO_URL=https://github.com/Jalappeno-apps/once-campfire.git
REPO_REF=main
EXISTING_CONTAINER=campfire
TARGET_IMAGE=ghcr.io/jalappeno-apps/once-campfire:v0.1.0
CANARY_HTTP_PORT=8080
CANARY_HTTPS_PORT=8443
RUN_CANARY=true
AUTO_DEPLOY=false
DEPLOY_MODE=canary # canary | direct
```

- `DEPLOY_MODE=canary` starts canary on `8080/8443` first (default).
- `DEPLOY_MODE=direct` skips canary and performs immediate cutover to `80/443`.
- In non-interactive (`curl | bash`) runs, `AUTO_DEPLOY=true` now auto-cutovers without prompting.

Example:

```bash
TARGET_IMAGE=ghcr.io/jalappeno-apps/once-campfire:v0.1.0 \
curl -fsSL https://raw.githubusercontent.com/Jalappeno-apps/once-campfire/main/script/install-or-upgrade-from-once | bash
```

Direct cutover one-liner (no canary):

```bash
DEPLOY_MODE=direct AUTO_DEPLOY=true \
curl -fsSL https://raw.githubusercontent.com/Jalappeno-apps/once-campfire/main/script/install-or-upgrade-from-once | bash
```

## What to edit in `.env.production`

The script opens `.env.production` in your `$EDITOR` and pre-fills what it can.
You must still confirm values before deploy, especially:

- `SECRET_KEY_BASE`
- `SSL_DOMAIN` or `DISABLE_SSL=true`
- `CAMPFIRE_IMAGE` (pin immutable tag for production)

## Cutover flow

After canary validation on `http://<server-ip>:8080`:

```bash
once stop
docker rm -f campfire || true
cd /opt/once-campfire/app
docker compose -f docker-compose.prod.yml -f docker-compose.bind-storage.yml --env-file .env.production up -d
```

Rollback:

```bash
cd /opt/once-campfire/app
docker compose -f docker-compose.prod.yml -f docker-compose.bind-storage.yml --env-file .env.production down
once start
```
