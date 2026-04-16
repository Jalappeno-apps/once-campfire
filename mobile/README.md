# Campfire Mobile (Expo starter)

This is a React Native starter wrapper for Campfire with:

- domain onboarding
- in-app WebView for full Campfire UI
- push permission + Expo push token capture

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

## 3) Notification behavior

- App requests push permissions after sign-in and generates a device push token.
- App registers this token with backend via `/api/mobile/devices`.
- Backend sends notifications through configured mobile push gateway.

## 4) For real background push

You still need backend support to deliver APNs/FCM/native pushes. Next step:

1. Ensure device token registration succeeds on sign-in.
2. Trigger push when Campfire receives new events.
3. Monitor provider ticket errors in server logs.

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
