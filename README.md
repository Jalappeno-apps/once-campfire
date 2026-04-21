# Campfire

A self-hosted team chat application. Run it on your own server — you own the data, the domain, and the infrastructure.

**Features:** rooms with access controls, direct messages, file attachments, search, @mentions, web push notifications, video calls (Jitsi), bot API, mobile apps (iOS + Android), and a desktop app (macOS, Windows, Linux).

---

## Contents

- [Deploy the server](#1-deploy-the-server)
- [Environment variables](#2-environment-variables)
- [First run](#3-first-run)
- [Upgrading](#4-upgrading)
- [Migrating from once-managed Campfire](#5-migrating-from-once-managed-campfire)
- [Video calls (Jitsi)](#6-video-calls-jitsi)
- [Mobile app (iOS & Android)](#7-mobile-app-ios--android)
- [Desktop app](#8-desktop-app)
- [Deep links](#9-deep-links)
- [Development](#10-development)

---

## 1. Deploy the server

The Docker image bundles everything: web app, background jobs, caching, file serving, and automatic SSL via Let's Encrypt.

**Step 1 — Create your env file**

```bash
cp .env.production.example .env.production
```

Edit `.env.production` and set at minimum:

```bash
SECRET_KEY_BASE=replace_with_long_random_secret
SSL_DOMAIN=chat.example.com
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
```

Generate a VAPID keypair (needed for browser push notifications):

```bash
docker run --rm ghcr.io/jalappeno-apps/once-campfire:main /rails/script/admin/create-vapid-key
```

**Step 2 — Run with Docker Compose (recommended)**

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production pull
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

Data is persisted in a Docker volume at `/rails/storage`. Messages, attachments, and the database all live there and survive container restarts and upgrades.

**Alternatively — plain Docker run**

```bash
docker run \
  --publish 80:80 --publish 443:443 \
  --restart unless-stopped \
  --volume campfire-storage:/rails/storage \
  --env SECRET_KEY_BASE=$YOUR_SECRET_KEY_BASE \
  --env VAPID_PUBLIC_KEY=$YOUR_PUBLIC_KEY \
  --env VAPID_PRIVATE_KEY=$YOUR_PRIVATE_KEY \
  --env SSL_DOMAIN=chat.example.com \
  ghcr.io/jalappeno-apps/once-campfire:main
```

---

## 2. Environment variables

| Variable | Required | Description |
|---|---|---|
| `SECRET_KEY_BASE` | ✅ | Long random secret for Rails encryption |
| `SSL_DOMAIN` | ✅* | Domain for automatic Let's Encrypt SSL |
| `DISABLE_SSL` | ✅* | Set to `true` to serve plain HTTP (e.g. behind a proxy) |
| `VAPID_PUBLIC_KEY` | Recommended | Web push notifications |
| `VAPID_PRIVATE_KEY` | Recommended | Web push notifications |
| `SENTRY_DSN` | Optional | Error reporting via Sentry |
| `MEET_BASE_URL` | Optional | Your Jitsi server URL, e.g. `https://meet.example.com` |
| `JITSI_JWT_APP_ID` | Optional | Jitsi token auth app ID |
| `JITSI_JWT_APP_SECRET` | Optional | Jitsi token auth signing secret |
| `MOBILE_PUSH_DELIVERY_URL` | Optional | Custom push gateway (defaults to Expo Push API) |

*Set either `SSL_DOMAIN` or `DISABLE_SSL`, not both.

---

## 3. First run

On first launch you'll be guided through creating an admin account. The admin's email address appears on the login page so users know who to contact if they forget their password. You can change it later in account settings.

Campfire is **single-tenant** — all users share the same workspace. To host multiple separate teams, run multiple instances.

---

## 4. Upgrading

**Step 1 — Back up first (always)**

```bash
script/admin/backup-container
```

This snapshots the SQLite database and archives `/rails/storage` to a local `./backups` directory.

**Step 2 — Pull and merge upstream changes**

```bash
git fetch upstream
git merge upstream/main
# resolve any conflicts, run tests
git push origin main
```

**Step 3 — Tag a release and publish a new image**

Pushing a version tag triggers the GitHub Action to build and push a new image to GHCR automatically:

```bash
git tag v1.2.0
git push origin v1.2.0
# image published as: ghcr.io/jalappeno-apps/once-campfire:v1.2.0
```

**Step 4 — Deploy the new image**

Update `CAMPFIRE_IMAGE` in `.env.production`:

```bash
CAMPFIRE_IMAGE=ghcr.io/jalappeno-apps/once-campfire:v1.2.0
```

Then redeploy:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production pull
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

**Rollback:** set `CAMPFIRE_IMAGE` back to the previous tag and redeploy. See `docs/FORK_DEPLOYMENT_RUNBOOK.md` for the full workflow.

> **Tip:** never deploy `:main` in production — always pin an immutable version tag so rollback is instant.

---

## 5. Migrating from once-managed Campfire

If you're currently running the official `once` Campfire and want to switch to this fork without losing data:

```bash
curl -fsSL https://raw.githubusercontent.com/Jalappeno-apps/once-campfire/main/script/install-or-upgrade-from-once | bash
```

The script detects your existing container, backs up data, migrates env vars, runs a canary deployment on port `8080` for validation, then prints cutover commands. See `docs/ONCE_UPGRADE_INSTALLER.md` for full options and override variables.

---

## 6. Video calls (Jitsi)

By default, calls use `https://meet.jit.si`. To use your own Jitsi server:

```bash
MEET_BASE_URL=https://meet.example.com
```

To require signed JWT tokens (so only Campfire-issued links can join):

```bash
JITSI_JWT_APP_ID=your-app-id
JITSI_JWT_APP_SECRET=your-signing-secret
JITSI_JWT_AUDIENCE=jitsi          # optional, default: jitsi
JITSI_JWT_TTL_SECONDS=7200        # optional, default: 7200
```

On the web, call links open in a new browser tab. On mobile, they open inside the app.

---

## 7. Mobile app (iOS & Android)

The mobile app is a native wrapper in `mobile/` built with Expo / React Native.

**Install and run locally**

```bash
cd mobile
npm install
npx expo start
```

Scan the QR code with Expo Go, or run on a simulator.

**Build for distribution (EAS)**

```bash
npm install -g eas-cli
eas build --platform all
```

Make sure `app.json` has your EAS project ID set:

```json
"extra": {
  "eas": { "projectId": "your-project-id" }
}
```

**After any native config change** (package name, scheme, new permissions), regenerate native projects:

```bash
npx expo prebuild --clean
```

**On first launch**, the app shows a "Connect your Campfire" screen. Enter your server domain (e.g. `chat.example.com`) and tap Save.

**Push notifications** are handled natively via Expo push tokens. The app registers the device with the server after sign-in. Requires a real device build (not Expo Go) for production push.

---

## 8. Desktop app

The desktop app is an Electron wrapper in `desktop/` for macOS, Windows, and Linux. It loads your Campfire server in a native window with OS notifications via the browser's built-in web push stack — no extra configuration needed.

**Run locally**

```bash
cd desktop
npm install
npm start
```

**Build installers**

```bash
npm run build:mac    # → .dmg + .zip
npm run build:win    # → .exe installer
npm run build:linux  # → .AppImage + .deb
```

Output goes to `desktop/dist/`. On first launch, enter your Campfire server domain. The setting is remembered across restarts. On macOS, the app lives in the menu bar and closing the window hides it rather than quitting.

---

## 9. Deep links

The mobile app registers the `campfire://` URL scheme. You can distribute a link that automatically connects users to your server:

```
campfire://connect?server=chat.example.com
```

Tapping this link on a device with the app installed opens it and skips the manual domain entry screen.

---

## 10. Development

```bash
bin/setup
bin/rails server
```

See `docs/FORK_DEPLOYMENT_RUNBOOK.md` for the full fork/upstream Git workflow and guidance on adding custom features with minimal merge pain.
