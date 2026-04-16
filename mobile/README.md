# Campfire Mobile (Expo starter)

This is a React Native starter wrapper for Campfire with:

- domain onboarding
- in-app WebView for full Campfire UI
- push permission + Expo push token capture
- optional polling endpoint to trigger local notifications

## 1) Install and run

```bash
cd mobile
npm install
npm run start
```

Run on iOS/Android with Expo Go or a dev build.

## 2) Connect to your Campfire server

On first launch, enter your hosted domain, for example:

`chat.example.com`

The app stores this as `https://chat.example.com`.

## 3) Notification behavior (current starter)

- App requests push permissions and tries to generate an Expo push token.
- In Settings:
  - configure a poll endpoint path (default: `/api/mobile/notifications`)
  - optionally set API token for polling
- App polls every 60 seconds while active and creates local notifications when
  unread count increases.

The endpoint can return:

- `{"unread_count": 3}`
- `{"notifications": [...]}` (array)
- `[ ... ]` (array)
- `3` (number)

## 4) For real background push

You still need backend support to deliver APNs/FCM/native pushes. Next step:

1. Add endpoint to register device token.
2. Trigger push when Campfire receives new events.
3. Replace/augment polling with server-delivered push notifications.

## 5) Important Expo config

Set a real EAS project id in `app.json`:

```json
"extra": {
  "eas": {
    "projectId": "your-real-project-id"
  }
}
```

Without this, push token generation is skipped.

## 6) Mobile push gateway endpoint

Backend delivery URL is configurable via:

`MOBILE_PUSH_DELIVERY_URL`

If unset, backend defaults to Expo Push API endpoint.
