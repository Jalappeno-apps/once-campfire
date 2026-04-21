# Campfire Desktop

Electron wrapper for Campfire. Loads your self-hosted Campfire server in a native window with OS notifications via the standard web push / service worker stack already built into Campfire.

## Development

```bash
cd desktop
npm install
npm start
```

## Building installers

```bash
# macOS (.dmg + .zip)
npm run build:mac

# Windows (.exe installer)
npm run build:win

# Linux (.AppImage + .deb)
npm run build:linux
```

Output goes to `desktop/dist/`.

## How notifications work

No extra configuration needed. Campfire's existing VAPID web push works natively in Electron's Chromium — the web app registers the service worker and handles push subscription automatically. OS notifications appear through the system notification center.
