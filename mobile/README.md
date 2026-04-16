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

To use **`http://`** (LAN, dev servers, no TLS), rebuild a **development or release client** after pulling: native projects must be regenerated so Android cleartext and iOS WebView ATS settings apply (`npx expo prebuild --clean` then `expo run:ios` / `expo run:android`, or EAS Build). Expo Go may not match these flags.

## 3) Notification behavior

- App requests push permissions after sign-in and generates a device push token.
- App registers this token with backend via `/api/mobile/devices`.
- Backend sends notifications through configured mobile push gateway.

## 4) For real background push

You still need backend support to deliver APNs/FCM/native pushes. Next step:

1. Ensure device token registratiookn.
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

## 7) In-app calls

- Room message `/meet` creates a unique Jitsi call invite link.
- In the native app, trusted call links (`https://meet.jit.si/...`) open inside the app.
- External links that are not on the Campfire domain or trusted call host are blocked from opening in the wrapper.
