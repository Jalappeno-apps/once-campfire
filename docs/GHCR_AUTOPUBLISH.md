# GHCR Auto Publish for Fork

Your fork already includes `.github/workflows/publish-image.yml`, which builds
and pushes multi-arch images to GHCR.

## How tags are produced

- Push to `main` -> publishes `ghcr.io/jalappeno-apps/once-campfire:main`
- Push a git tag like `v1.2.3` -> publishes:
  - `:v1.2.3`
  - `:1.2.3`
  - `:1.2`
  - `:1`
  - `:latest`
- Any push also publishes a short SHA tag like `:sha-abc1234`

## One-time GitHub setup

1. In your fork, go to **Settings -> Actions -> General**
2. Ensure Actions are enabled for this repository.
3. Keep default `GITHUB_TOKEN` permissions (workflow has explicit package write).
4. In package settings for GHCR image, keep visibility private/public as desired.

## Release workflow

Use immutable release tags for production:

```bash
git checkout main
git pull --ff-only origin main
git tag v0.1.0
git push origin v0.1.0
```

Then set in `.env.production`:

```bash
CAMPFIRE_IMAGE=ghcr.io/jalappeno-apps/once-campfire:v0.1.0
```

Deploy:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production pull
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

## Recommended production rule

- Do not deploy `:main` in production.
- Deploy only fixed tags (`vX.Y.Z`) so rollback is instant.
