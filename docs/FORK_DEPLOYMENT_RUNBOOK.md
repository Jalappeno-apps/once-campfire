# Fork Deployment Runbook

This runbook helps you safely operate a custom Campfire fork while keeping your
existing data and still pulling upstream updates.

## 1) One-time Git remotes setup

In your local clone:

```bash
git remote -v
git remote add upstream https://github.com/basecamp/once-campfire.git
git remote set-url origin https://github.com/Jalappeno-apps/once-campfire.git
git fetch upstream origin
```

- `origin` = your fork (where your custom code lives).
- `upstream` = official Basecamp repo (where updates come from).

## 2) Production environment file

Create your production env file from the template:

```bash
cp .env.production.example .env.production
```

Then fill in at least:

- `SECRET_KEY_BASE`
- `SSL_DOMAIN` (or set `DISABLE_SSL=true`)
- `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` if you use web push.

## 3) Safe deploy with Docker Compose

Use `docker-compose.prod.yml` from this repo. It mounts persistent data at
`/rails/storage`, so messages/files survive code updates and container restarts.

Deploy:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production pull
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

## 4) Backup before every deploy

Run:

```bash
script/admin/backup-container
```

This script:

1. Creates a consistent SQLite snapshot in `storage/backups` inside container.
2. Archives `/rails/storage` from the running container.
3. Copies archive to local `./backups`.

You can override defaults:

```bash
CAMPFIRE_CONTAINER=campfire BACKUP_DIR=./backups script/admin/backup-container
```

## 5) Upstream updates workflow

On a dedicated branch:

```bash
git checkout main
git fetch upstream
git merge upstream/main
```

Resolve conflicts, run tests, then push your fork:

```bash
git push origin main
```

Build/publish your image tag and set `CAMPFIRE_IMAGE` in `.env.production` to
that exact immutable tag, then redeploy with compose.

For exact GHCR release/tag behavior from this fork, see
`docs/GHCR_AUTOPUBLISH.md`.

## 6) Rollback strategy

Rollback should be image-based first:

1. Keep the previous known-good image tag.
2. Set `CAMPFIRE_IMAGE` back to that tag in `.env.production`.
3. `docker compose -f docker-compose.prod.yml --env-file .env.production up -d`

If data corruption is suspected, stop app, restore from a backup archive, and
start app again.

## 7) Where to place custom features

To minimize merge pain with upstream:

- Keep Campfire core changes small and isolated.
- Add new integrations behind feature flags/env vars.
- For mobile push and future calls/video, prefer companion services:
  - Push service for APNs/FCM token handling + delivery.
  - Realtime/call service (for example LiveKit/Jitsi signaling) separate from
    the core chat app.

This keeps your fork update-friendly while letting you extend features quickly.
