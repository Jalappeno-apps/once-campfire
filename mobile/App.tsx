import AsyncStorage from "@react-native-async-storage/async-storage";
import Constants from "expo-constants";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { StatusBar } from "expo-status-bar";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  AppState,
  Image,
  Linking,
  PermissionsAndroid,
  Vibration,
  useColorScheme,
  KeyboardAvoidingView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  Platform,
  View
} from "react-native";
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { WebView, WebViewMessageEvent } from "react-native-webview";

const APP_NAME = "Campfire";
const APP_LOGO = require("./logo.png");

const STORAGE_KEYS = {
  domain: "campfire.mobile.domain"
} as const;
const CALL_NOTIFICATION_CATEGORY_ID = "incoming_call";
const CALL_ACTION_ACCEPT = "accept_call";
const CALL_ACTION_DECLINE = "decline_call";
const INCOMING_CALL_VIBRATION_PATTERN = [0, 750, 450, 750];
/** Height of the minimized Jitsi strip; must match reserved space on the chat WebView below */
const MINIMIZED_CALL_DOCK_HEIGHT = 58;

async function configureCallNotificationActions(): Promise<void> {
  await Notifications.setNotificationCategoryAsync(CALL_NOTIFICATION_CATEGORY_ID, [
    { identifier: CALL_ACTION_ACCEPT, buttonTitle: "Accept", options: { opensAppToForeground: true } },
    {
      identifier: CALL_ACTION_DECLINE,
      buttonTitle: "Decline",
      options: { isDestructive: true, opensAppToForeground: true }
    }
  ]);
}

Notifications.setNotificationHandler({
  handleNotification: async (notification) => {
    const data = notification.request.content.data as { type?: unknown } | null | undefined;
    const type = typeof data?.type === "string" ? data.type : null;

    return {
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: type === "incoming_call",
      shouldSetBadge: false
    };
  }
});

function normalizeDomain(rawDomain: string): string | null {
  const trimmed = rawDomain.trim();
  if (!trimmed) return null;
  const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  try {
    const parsed = new URL(withProtocol);
    if (!parsed.hostname) return null;
    return parsed.origin;
  } catch {
    return null;
  }
}

function extractServerFromDeepLink(url: string | null | undefined): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "campfire:") return null;
    if (parsed.hostname !== "connect") return null;
    const server = parsed.searchParams.get("server");
    return normalizeDomain(server ?? "");
  } catch {
    return null;
  }
}

function isSettingsLikePath(url: string): boolean {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    return (
      parsed.pathname.includes("/profile") ||
      parsed.pathname.includes("/account") ||
      parsed.pathname.includes("/settings")
    );
  } catch {
    return false;
  }
}

function extractNotificationPath(response: Notifications.NotificationResponse | null): string | null {
  if (!response) return null;
  const data = response.notification.request.content.data as { path?: unknown } | null | undefined;
  return typeof data?.path === "string" ? data.path : null;
}

type IncomingCallPayload = {
  callUrl: string;
  title: string;
  body: string;
  path: string | null;
  messageId?: number;
};

const DISMISSED_INCOMING_CALLS_KEY = "campfire.dismissedIncomingCalls.v1";
const DISMISSED_CALL_TTL_MS = 24 * 60 * 60 * 1000;

type DismissedIncomingEntry = { key: string; until: number };

function parseMessageIdFromData(data: Record<string, unknown>): number | undefined {
  const raw = data.message_id;
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;
  if (typeof raw === "string" && /^\d+$/.test(raw)) return parseInt(raw, 10);
  return undefined;
}

function incomingCallDedupKey(callUrl: string, messageId?: number): string {
  if (messageId != null) return `m:${messageId}`;
  return `u:${callUrl}`;
}

async function loadDismissedIncomingKeys(): Promise<Set<string>> {
  try {
    const raw = await AsyncStorage.getItem(DISMISSED_INCOMING_CALLS_KEY);
    if (!raw) return new Set();
    const entries = JSON.parse(raw) as DismissedIncomingEntry[];
    const now = Date.now();
    const valid = entries.filter((e) => typeof e.key === "string" && e.until > now);
    if (valid.length !== entries.length) {
      await AsyncStorage.setItem(DISMISSED_INCOMING_CALLS_KEY, JSON.stringify(valid));
    }
    return new Set(valid.map((e) => e.key));
  } catch {
    return new Set();
  }
}

async function persistDismissedIncomingKey(key: string): Promise<void> {
  try {
    const raw = await AsyncStorage.getItem(DISMISSED_INCOMING_CALLS_KEY);
    const entries: DismissedIncomingEntry[] = raw ? JSON.parse(raw) : [];
    const now = Date.now();
    const filtered = entries.filter((e) => e.until > now && e.key !== key);
    filtered.push({ key, until: now + DISMISSED_CALL_TTL_MS });
    await AsyncStorage.setItem(DISMISSED_INCOMING_CALLS_KEY, JSON.stringify(filtered));
  } catch {
    // ignore storage failures
  }
}

function extractIncomingCallPayload(content: {
  title?: string | null;
  body?: string | null;
  data?: Record<string, unknown> | null;
} | null): IncomingCallPayload | null {
  if (!content) return null;
  const data = content.data ?? {};
  if (data.type !== "incoming_call") return null;
  if (typeof data.call_url !== "string" || !data.call_url) return null;

  const path = typeof data.path === "string" && data.path ? data.path : null;
  const messageId = parseMessageIdFromData(data);
  return {
    callUrl: data.call_url,
    title: typeof content.title === "string" && content.title ? content.title : "Incoming call",
    body: typeof content.body === "string" && content.body ? content.body : "Join call",
    path,
    messageId
  };
}

function resolveNotificationUrl(domain: string, rawPath: string): string | null {
  const trimmed = rawPath.trim();
  if (!trimmed) return null;

  try {
    const base = new URL(domain);
    const resolved = new URL(trimmed, base);
    // Only allow in-app navigation to current Campfire domain.
    if (resolved.origin !== base.origin) return null;
    return resolved.toString();
  } catch {
    return null;
  }
}

function resolveTrustedCallUrl(rawUrl: string, trustedHosts: string[]): string | null {
  if (!rawUrl) return null;
  try {
    const parsed = new URL(rawUrl);
    return trustedHosts.includes(parsed.hostname) ? parsed.toString() : null;
  } catch {
    return null;
  }
}

function isAllowedExternalUrl(rawUrl: string): boolean {
  try {
    const parsed = new URL(rawUrl);
    const host = parsed.hostname.toLowerCase();
    return (
      host === "calendar.google.com" ||
      host === "www.google.com" ||
      host.endsWith(".google.com")
    );
  } catch {
    return false;
  }
}

function areStringArraysEqual(left: string[], right: string[]): boolean {
  if (left.length !== right.length) return false;
  return left.every((value, index) => value === right[index]);
}

async function ensureCallPermissions(): Promise<boolean> {
  if (Platform.OS !== "android") return true;

  const requiredPermissions = [
    PermissionsAndroid.PERMISSIONS.CAMERA,
    PermissionsAndroid.PERMISSIONS.RECORD_AUDIO
  ];

  const checks = await Promise.all(requiredPermissions.map((permission) => PermissionsAndroid.check(permission)));
  if (checks.every(Boolean)) return true;

  const requested = await PermissionsAndroid.requestMultiple(requiredPermissions);
  return requiredPermissions.every((permission) => requested[permission] === PermissionsAndroid.RESULTS.GRANTED);
}

async function registerForPushTokenAsync(): Promise<string | null> {
  if (!Device.isDevice) return null;
  if (Constants.appOwnership === "expo") return null;

  await configureCallNotificationActions();

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("default", {
      name: "default",
      importance: Notifications.AndroidImportance.MAX
    });
    await Notifications.setNotificationChannelAsync("calls", {
      name: "Calls",
      importance: Notifications.AndroidImportance.MAX,
      vibrationPattern: [0, 900, 400, 900, 400, 900],
      lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC
    });
  }

  const existing = await Notifications.getPermissionsAsync();
  let finalStatus = existing.status;
  if (existing.status !== "granted") {
    const requested = await Notifications.requestPermissionsAsync();
    finalStatus = requested.status;
  }

  if (finalStatus !== "granted") return null;

  const projectId = Constants.expoConfig?.extra?.eas?.projectId;
  if (!projectId || typeof projectId !== "string" || projectId.includes("replace-with")) {
    return null;
  }

  try {
    const token = await Notifications.getExpoPushTokenAsync({ projectId });
    return token.data;
  } catch {
    return null;
  }
}

function AppContent() {
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const isDark = colorScheme === "dark";
  const colors = isDark ? {
    background: "#0f1115",
    surface: "#171a21",
    border: "#2a2f3a",
    text: "#e8edf7",
    subtext: "#a6afc1",
    primary: "#4a86ff",
    primaryText: "#ffffff",
    inputBackground: "#11151d"
  } : {
    background: "#f7f8fa",
    surface: "#ffffff",
    border: "#dfe3ea",
    text: "#2f3440",
    subtext: "#5a6270",
    primary: "#246bff",
    primaryText: "#ffffff",
    inputBackground: "#ffffff"
  };

  const [loading, setLoading] = useState(true);
  const [domain, setDomain] = useState<string | null>(null);
  const [domainInput, setDomainInput] = useState("");
  const [showSettings, setShowSettings] = useState(false);
  const [authUserId, setAuthUserId] = useState<number | null>(null);
  const [pushToken, setPushToken] = useState<string | null>(null);
  const [permissionStatus, setPermissionStatus] = useState<Notifications.PermissionStatus | "unknown">("unknown");
  const [pushRegistrationStatus, setPushRegistrationStatus] = useState("Waiting for sign-in");
  const [currentWebUrl, setCurrentWebUrl] = useState("");
  const [pendingNotificationPath, setPendingNotificationPath] = useState<string | null>(null);
  const [webViewSourceUrl, setWebViewSourceUrl] = useState<string | null>(null);
  const [activeCallUrl, setActiveCallUrl] = useState<string | null>(null);
  const [callMinimized, setCallMinimized] = useState(false);
  const [incomingCall, setIncomingCall] = useState<IncomingCallPayload | null>(null);
  const [webViewError, setWebViewError] = useState<string | null>(null);
  const [trustedCallHosts, setTrustedCallHosts] = useState<string[]>(["meet.jit.si"]);
  const webViewRef = useRef<WebView>(null);
  const dismissedIncomingKeysRef = useRef<Set<string>>(new Set());
  const seenNotificationIdsRef = useRef<Set<string>>(new Set());
  const shouldShowServerButton = useMemo(() => {
    return !showSettings && (Boolean(webViewError) || isSettingsLikePath(currentWebUrl));
  }, [showSettings, webViewError, currentWebUrl]);

  const markIncomingCallDismissed = useCallback((payload: IncomingCallPayload) => {
    const key = incomingCallDedupKey(payload.callUrl, payload.messageId);
    dismissedIncomingKeysRef.current.add(key);
    void persistDismissedIncomingKey(key);
  }, []);

  const shouldSuppressIncomingCall = useCallback((payload: IncomingCallPayload) => {
    const key = incomingCallDedupKey(payload.callUrl, payload.messageId);
    return dismissedIncomingKeysRef.current.has(key);
  }, []);

  useEffect(() => {
    void loadDismissedIncomingKeys().then((set) => {
      dismissedIncomingKeysRef.current = set;
    });
  }, []);

  const tryOpenCallUrl = useCallback((rawUrl: string): boolean => {
    const callUrl = resolveTrustedCallUrl(rawUrl, trustedCallHosts);
    if (!callUrl) return false;

    void (async () => {
      const granted = await ensureCallPermissions();
      if (!granted) {
        Alert.alert(
          "Camera and microphone required",
          "Allow camera and microphone access to join calls.",
          [
            { text: "Not now", style: "cancel" },
            { text: "Open app settings", onPress: () => void Linking.openSettings() }
          ]
        );
        return;
      }

      setShowSettings(false);
      setActiveCallUrl(callUrl);
      setIncomingCall(null);
    })();

    return true;
  }, [trustedCallHosts]);

  const navigateWebViewToUrl = useCallback((targetUrl: string) => {
    if (tryOpenCallUrl(targetUrl)) return;

    setShowSettings(false);
    setWebViewError(null);
    setWebViewSourceUrl(targetUrl);
    setCurrentWebUrl(targetUrl);
    if (webViewRef.current) {
      webViewRef.current.injectJavaScript(`window.location.assign(${JSON.stringify(targetUrl)}); true;`);
    }
  }, [tryOpenCallUrl]);

  const handleNotificationResponse = useCallback((response: Notifications.NotificationResponse | null): boolean => {
    if (!response) return false;

    const callPayload = extractIncomingCallPayload(response.notification.request.content as {
      title?: string | null;
      body?: string | null;
      data?: Record<string, unknown> | null;
    });

    if (!callPayload) return false;

    if (response.actionIdentifier === CALL_ACTION_DECLINE) {
      void Notifications.dismissNotificationAsync(response.notification.request.identifier);
      markIncomingCallDismissed(callPayload);
      setIncomingCall(null);
      return true;
    }

    if (response.actionIdentifier === CALL_ACTION_ACCEPT) {
      void Notifications.dismissNotificationAsync(response.notification.request.identifier);
      setIncomingCall(callPayload);
      const didOpen = tryOpenCallUrl(callPayload.callUrl);
      if (!didOpen && callPayload.path) setPendingNotificationPath(callPayload.path);
      return true;
    }

    setIncomingCall(callPayload);
    return true;
  }, [tryOpenCallUrl, markIncomingCallDismissed]);

  const refreshAuthSession = useCallback(async () => {
    if (!domain) return;

    try {
      const response = await fetch(`${domain}/api/mobile/session?t=${Date.now()}`, {
        method: "GET",
        credentials: "include",
        headers: {
          Accept: "application/json",
          "Cache-Control": "no-cache",
          Pragma: "no-cache"
        }
      });

      if (response.status === 401) {
        setAuthUserId(null);
        return;
      }

      if (!response.ok) return;

      const payload = (await response.json()) as { user_id?: number; trusted_call_hosts?: unknown };
      setAuthUserId(typeof payload.user_id === "number" ? payload.user_id : null);
      if (Array.isArray(payload.trusted_call_hosts)) {
        const safeHosts = payload.trusted_call_hosts.filter((entry): entry is string => typeof entry === "string" && entry.length > 0);
        if (safeHosts.length > 0) {
          setTrustedCallHosts((previous) => (areStringArraysEqual(previous, safeHosts) ? previous : safeHosts));
        }
      }
    } catch {
      // Ignore transient network failures and keep current auth state.
    }
  }, [domain]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const storedDomain = await AsyncStorage.getItem(STORAGE_KEYS.domain);

      const initialUrl = await Linking.getInitialURL();
      const deepLinkedServer = extractServerFromDeepLink(initialUrl);

      if (!mounted) return;

      if (deepLinkedServer) {
        await AsyncStorage.setItem(STORAGE_KEYS.domain, deepLinkedServer);
        setDomain(deepLinkedServer);
        setDomainInput(deepLinkedServer);
      } else if (storedDomain) {
        setDomain(storedDomain);
        setDomainInput(storedDomain);
      }

      if (mounted) setLoading(false);
    })();

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    const sub = Linking.addEventListener("url", ({ url }) => {
      const server = extractServerFromDeepLink(url);
      if (!server) return;
      void AsyncStorage.setItem(STORAGE_KEYS.domain, server).then(() => {
        setDomain(server);
        setDomainInput(server);
        setWebViewSourceUrl(server);
        setWebViewError(null);
        setShowSettings(false);
      });
    });
    return () => sub.remove();
  }, []);

  useEffect(() => {
    void configureCallNotificationActions();
  }, []);

  useEffect(() => {
    const sub = AppState.addEventListener("change", (nextState) => {
      if (nextState === "active") {
        void refreshAuthSession();
      }
    });
    return () => sub.remove();
  }, [refreshAuthSession]);

  useEffect(() => {
    if (activeCallUrl) setCallMinimized(false);
  }, [activeCallUrl]);

  useEffect(() => {
    if (!domain) return;
    void refreshAuthSession();
  }, [domain, refreshAuthSession]);

  useEffect(() => {
    if (!domain) return;
    setWebViewSourceUrl(domain);
  }, [domain]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const initialResponse = await Notifications.getLastNotificationResponseAsync();
      if (!mounted) return;
      if (handleNotificationResponse(initialResponse)) return;
      const initialPath = extractNotificationPath(initialResponse);
      if (initialPath) setPendingNotificationPath(initialPath);
    })();

    const receivedSub = Notifications.addNotificationReceivedListener((notification) => {
      const nid = notification.request.identifier;
      if (seenNotificationIdsRef.current.has(nid)) return;
      seenNotificationIdsRef.current.add(nid);

      const callPayload = extractIncomingCallPayload(notification.request.content as {
        title?: string | null;
        body?: string | null;
        data?: Record<string, unknown> | null;
      });
      if (callPayload) {
        if (shouldSuppressIncomingCall(callPayload)) return;
        setIncomingCall(callPayload);
      }
    });

    const responseSub = Notifications.addNotificationResponseReceivedListener((response) => {
      if (handleNotificationResponse(response)) return;

      const path = extractNotificationPath(response);
      if (path) setPendingNotificationPath(path);
    });

    return () => {
      mounted = false;
      receivedSub.remove();
      responseSub.remove();
    };
  }, [handleNotificationResponse, shouldSuppressIncomingCall]);

  useEffect(() => {
    if (!domain || !pendingNotificationPath) return;
    const targetUrl = resolveNotificationUrl(domain, pendingNotificationPath);
    if (targetUrl) navigateWebViewToUrl(targetUrl);
    setPendingNotificationPath(null);
  }, [domain, pendingNotificationPath, navigateWebViewToUrl]);

  useEffect(() => {
    if (!incomingCall || activeCallUrl) {
      Vibration.cancel();
      return;
    }

    Vibration.vibrate(INCOMING_CALL_VIBRATION_PATTERN);
    const interval = setInterval(() => {
      Vibration.vibrate(INCOMING_CALL_VIBRATION_PATTERN);
    }, 2400);

    return () => {
      clearInterval(interval);
      Vibration.cancel();
    };
  }, [incomingCall, activeCallUrl]);

  /** Leaving the room (or app web UI) without accepting clears the overlay and remembers dismiss so repeat pushes don’t re-open it. */
  useEffect(() => {
    if (!incomingCall || !domain || !currentWebUrl) return;
    if (!incomingCall.path) return;
    try {
      const roomPath = new URL(incomingCall.path, domain).pathname;
      const curPath = new URL(currentWebUrl).pathname;
      const stillInRoom = curPath === roomPath || curPath.startsWith(`${roomPath}/`);
      if (!stillInRoom) {
        markIncomingCallDismissed(incomingCall);
        setIncomingCall(null);
      }
    } catch {
      // ignore URL parse errors
    }
  }, [currentWebUrl, incomingCall, domain, markIncomingCallDismissed]);

  const ensurePushRegistration = useCallback(async () => {
    if (!authUserId) {
      setPushRegistrationStatus("Sign in to enable push");
      return;
    }

    if (Constants.appOwnership === "expo") {
      setPushRegistrationStatus("Push unavailable in Expo Go. Use development build.");
      return;
    }

    const before = await Notifications.getPermissionsAsync();
    setPermissionStatus(before.status);

    setPushRegistrationStatus("Requesting notification permission...");
    const token = await registerForPushTokenAsync();

    const after = await Notifications.getPermissionsAsync();
    setPermissionStatus(after.status);

    if (token) {
      setPushToken(token);
      setPushRegistrationStatus("Token ready");
    } else if (after.status === "denied") {
      setPushRegistrationStatus("Permission denied in system settings");
    } else {
      setPushRegistrationStatus("Permission unavailable");
    }
  }, [authUserId]);

  useEffect(() => {
    if (!authUserId) {
      setPushRegistrationStatus("Sign in to enable push");
      return;
    }

    if (pushToken) return;

    async function ensurePushToken() {
      await ensurePushRegistration();
    }

    void ensurePushToken();
  }, [authUserId, pushToken, ensurePushRegistration]);

  useEffect(() => {
    if (!domain || !pushToken || !authUserId) return;

    let cancelled = false;
    const url = `${domain}/api/mobile/devices`;

    async function registerDevice() {
      try {
        const response = await fetch(url, {
          method: "POST",
          credentials: "include",
          headers: {
            Accept: "application/json",
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            device: {
              expo_push_token: pushToken,
              platform: Platform.OS,
              device_name: Device.deviceName ?? "unknown"
            }
          })
        });

        if (cancelled) return;

        if (response.ok) {
          setPushRegistrationStatus("Registered on server");
        } else if (response.status === 401) {
          setAuthUserId(null);
          setPushRegistrationStatus("Sign in to enable push");
        } else {
          setPushRegistrationStatus(`Registration failed (${response.status})`);
        }
      } catch {
        if (!cancelled) setPushRegistrationStatus("Registration failed (network error)");
      }
    }

    void registerDevice();
    return () => {
      cancelled = true;
    };
  }, [domain, pushToken, authUserId]);

  async function saveDomain() {
    const normalized = normalizeDomain(domainInput);
    if (!normalized) {
      Alert.alert("Invalid domain", "Enter a valid host, e.g. chat.example.com");
      return;
    }

    const switchingServers = Boolean(domain && normalized !== domain);
    if (switchingServers && domain) {
      try {
        await fetch(`${domain}/api/mobile/session`, {
          method: "DELETE",
          credentials: "include",
          headers: { Accept: "application/json" }
        });
      } catch {
        // Best effort logout before switching servers.
      }

      setAuthUserId(null);
      setPushRegistrationStatus("Waiting for sign-in");
    }

    await AsyncStorage.setItem(STORAGE_KEYS.domain, normalized);
    setDomain(normalized);
    setWebViewSourceUrl(normalized);
    setWebViewError(null);
    setShowSettings(false);
  }

  function handleWebViewMessage(event: WebViewMessageEvent) {
    try {
      const payload = JSON.parse(event.nativeEvent.data) as { type?: string };
      if (payload.type === "open-app-settings") {
        setShowSettings(true);
      } else if (payload.type === "close-app-settings") {
        setShowSettings(false);
      }
    } catch {
      // Ignore non-JSON bridge messages from webpages.
    }
  }

  function handleWebViewLoadEnd() {
    void refreshAuthSession();
  }

  function handleWebViewError(event: { nativeEvent?: { description?: string } }) {
    const description = event.nativeEvent?.description?.trim();
    setWebViewError(description || "Could not load your Campfire domain. Check the server URL and try again.");
    setShowSettings(true);
  }

  function handleShouldStartLoad(request: { url: string }): boolean {
    if (!domain) return true;

    if (tryOpenCallUrl(request.url)) return false;
    if (isAllowedExternalUrl(request.url)) {
      void Linking.openURL(request.url);
      return false;
    }

    try {
      const requestedUrl = new URL(request.url);
      const appOrigin = new URL(domain).origin;
      // Keep browsing constrained to the configured Campfire domain.
      return requestedUrl.origin === appOrigin;
    } catch {
      return false;
    }
  }

  function handleOpenWindow(event: { nativeEvent?: { targetUrl?: string } }) {
    const targetUrl = event.nativeEvent?.targetUrl;
    if (!targetUrl) return;

    if (tryOpenCallUrl(targetUrl)) return;
    if (isAllowedExternalUrl(targetUrl)) {
      void Linking.openURL(targetUrl);
      return;
    }

    try {
      const appOrigin = domain ? new URL(domain).origin : null;
      const requestedUrl = new URL(targetUrl);
      if (appOrigin && requestedUrl.origin === appOrigin) {
        navigateWebViewToUrl(targetUrl);
      }
    } catch {
      // Ignore malformed popup targets.
    }
  }

  if (loading) {
    return (
      <SafeAreaView edges={["top"]} style={[styles.center, { backgroundColor: colors.background }]}>
        <StatusBar style={isDark ? "light" : "dark"} backgroundColor={colors.background} />
        <ActivityIndicator size="large" />
        <Text style={[styles.helperText, { color: colors.subtext }]}>Preparing app...</Text>
      </SafeAreaView>
    );
  }

  if (!domain) {
    return (
      <SafeAreaView edges={["top"]} style={[styles.container, { backgroundColor: colors.background }]}>
        <StatusBar style={isDark ? "light" : "dark"} backgroundColor={colors.background} />
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === "ios" ? "padding" : undefined}>
        <ScrollView contentContainerStyle={styles.onboardingScroll} keyboardShouldPersistTaps="handled">
          <Image source={APP_LOGO} style={styles.onboardingLogo} />
          <Text style={[styles.onboardingTitle, { color: colors.text }]}>Welcome to Campfire</Text>
          <Text style={[styles.onboardingSubtitle, { color: colors.subtext }]}>
            Real-time team chat with messaging, file sharing, and video calls — powered by your own server.
          </Text>

          <View style={[styles.card, { backgroundColor: colors.surface }]}>
            <Text style={[styles.onboardingStepTitle, { color: colors.text }]}>Getting started</Text>
            <Text style={[styles.onboardingStep, { color: colors.subtext }]}>
              1.{" "}Your team admin sets up a Campfire server and sends you an invite.
            </Text>
            <Text style={[styles.onboardingStep, { color: colors.subtext }]}>
              2.{" "}Enter your server address below and sign in.
            </Text>
            <Text style={[styles.onboardingStep, { color: colors.subtext }]}>
              3.{" "}Start chatting with your team instantly.
            </Text>

            <TouchableOpacity onPress={() => void Linking.openURL("https://once.com/campfire")}>
              <Text style={[styles.onboardingLink, { color: colors.primary }]}>
                Learn more at once.com/campfire →
              </Text>
            </TouchableOpacity>
          </View>

          <View style={[styles.card, { backgroundColor: colors.surface }]}>
            <Text style={[styles.onboardingStepTitle, { color: colors.text }]}>Connect your server</Text>
            <Text style={[styles.helperText, { color: colors.subtext }]}>Enter the domain where your Campfire is hosted.</Text>
            <TextInput
              value={domainInput}
              onChangeText={setDomainInput}
              placeholder="chat.example.com"
              placeholderTextColor={colors.subtext}
              autoCapitalize="none"
              autoCorrect={false}
              style={[styles.input, { borderColor: colors.border, backgroundColor: colors.inputBackground, color: colors.text }]}
            />
            <TouchableOpacity style={[styles.button, { backgroundColor: colors.primary }]} onPress={() => void saveDomain()}>
              <Text style={[styles.buttonLabel, { color: colors.primaryText }]}>Connect</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView edges={["top"]} style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar style={isDark ? "light" : "dark"} backgroundColor={colors.background} />
      {shouldShowServerButton && (
        <TouchableOpacity
          style={[
            styles.floatingSettingsButton,
            {
              bottom: Math.max(insets.bottom + 16, 24),
              backgroundColor: colors.surface,
              borderColor: colors.border
            }
          ]}
          onPress={() => setShowSettings(true)}
        >
          <Text style={[styles.floatingSettingsButtonLabel, { color: colors.text }]}>Server</Text>
        </TouchableOpacity>
      )}

      {showSettings && (
        <ScrollView style={[styles.settingsCard, { backgroundColor: colors.surface, borderBottomColor: colors.border }]}>
          <View style={styles.settingsHeader}>
            <View style={styles.brandWrap}>
              <Image source={APP_LOGO} style={styles.brandLogo} />
              <View style={styles.brandTextWrap}>
                <Text style={[styles.brandNameText, { color: colors.text }]}>{APP_NAME}</Text>
                <Text style={[styles.domainText, { color: colors.subtext }]}>{domain}</Text>
              </View>
            </View>
            <TouchableOpacity style={[styles.topBarSettingsButton, { backgroundColor: colors.primary }]} onPress={() => setShowSettings(false)}>
              <Text style={[styles.topBarSettingsButtonLabel, { color: colors.primaryText }]}>Close</Text>
            </TouchableOpacity>
          </View>

          <Text style={[styles.settingsTitle, { color: colors.text }]}>App settings</Text>
          {webViewError && (
            <Text style={[styles.errorText, { color: "#c0392b" }]}>
              {webViewError}
            </Text>
          )}

          <Text style={[styles.label, { color: colors.text }]}>Campfire domain</Text>
          <TextInput
            value={domainInput || domain}
            onChangeText={setDomainInput}
            autoCapitalize="none"
            autoCorrect={false}
            placeholderTextColor={colors.subtext}
            style={[styles.input, { borderColor: colors.border, backgroundColor: colors.inputBackground, color: colors.text }]}
          />
          <TouchableOpacity style={[styles.buttonSecondary, { borderColor: colors.primary }]} onPress={() => void saveDomain()}>
            <Text style={[styles.buttonSecondaryLabel, { color: colors.primary }]}>Update domain</Text>
          </TouchableOpacity>

          <Text style={[styles.label, { color: colors.text }]}>Device push token</Text>
          <Text style={[styles.tokenText, { color: colors.text }]}>
            {pushToken ?? "Unavailable in Expo Go. Use a development build with EAS project id for remote push."}
          </Text>
          <Text style={[styles.helperText, { color: colors.subtext }]}>Permission status: {permissionStatus}</Text>
          <Text style={[styles.helperText, { color: colors.subtext }]}>Push registration: {pushRegistrationStatus}</Text>
          {permissionStatus !== "granted" && (
            <TouchableOpacity style={[styles.buttonSecondary, { borderColor: colors.primary }]} onPress={() => void ensurePushRegistration()}>
              <Text style={[styles.buttonSecondaryLabel, { color: colors.primary }]}>Enable notifications</Text>
            </TouchableOpacity>
          )}
          {permissionStatus === "denied" && (
            <TouchableOpacity style={[styles.buttonSecondary, { borderColor: colors.primary }]} onPress={() => void Linking.openSettings()}>
              <Text style={[styles.buttonSecondaryLabel, { color: colors.primary }]}>Open app settings</Text>
            </TouchableOpacity>
          )}
          <Text style={[styles.helperText, { color: colors.subtext }]}>
            Later, send this token to your backend/companion push service to deliver native push.
          </Text>
        </ScrollView>
      )}

      <View
        style={[
          styles.webviewWrap,
          { backgroundColor: colors.background },
          activeCallUrl &&
            callMinimized && {
              paddingBottom: MINIMIZED_CALL_DOCK_HEIGHT + insets.bottom
            }
        ]}
      >
        <WebView
          ref={webViewRef}
          style={{ flex: 1, backgroundColor: "#0f1115" }}
          source={{ uri: webViewSourceUrl ?? domain }}
          sharedCookiesEnabled
          thirdPartyCookiesEnabled
          setSupportMultipleWindows
          onOpenWindow={handleOpenWindow}
          onShouldStartLoadWithRequest={handleShouldStartLoad}
          applicationNameForUserAgent="CampfireMobileApp/1"
          hideKeyboardAccessoryView
          injectedJavaScriptBeforeContentLoaded={`
            window.__CAMPFIRE_NATIVE_APP__ = true;
            window.__CAMPFIRE_NATIVE_APP_PLATFORM__ = "react-native";
            window.CampfireNative = {
              openSettings: function() {
                if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
                  window.ReactNativeWebView.postMessage(JSON.stringify({ type: "open-app-settings" }));
                }
              },
              closeSettings: function() {
                if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
                  window.ReactNativeWebView.postMessage(JSON.stringify({ type: "close-app-settings" }));
                }
              }
            };
            (function() {
              // Native SafeAreaView handles the top inset — remove viewport-fit=cover so
              // env(safe-area-inset-top) returns 0 and the web app doesn't double-pad.
              var meta = document.querySelector('meta[name="viewport"]');
              if (meta) {
                meta.setAttribute('content', meta.getAttribute('content').replace(/,?\\s*viewport-fit=cover/i, ''));
              }
              function boot() {
                var root = document.documentElement;
                var raf = 0;
                function syncKeyboardInset() {
                  if (!window.visualViewport) return;
                  var vv = window.visualViewport;
                  var inset = Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
                  root.style.setProperty("--campfire-keyboard-overlay", inset + "px");
                }
                function scheduleSync() {
                  if (raf) return;
                  raf = requestAnimationFrame(function() {
                    raf = 0;
                    syncKeyboardInset();
                  });
                }
                if (window.visualViewport) {
                  window.visualViewport.addEventListener("resize", scheduleSync);
                  scheduleSync();
                }
              }
              if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
              else boot();
            })();
            true;
          `}
          onMessage={handleWebViewMessage}
          onNavigationStateChange={(navState) => setCurrentWebUrl(navState.url)}
          onLoadEnd={handleWebViewLoadEnd}
          onError={handleWebViewError}
          onHttpError={() => handleWebViewError({})}
          {...(Platform.OS === "android" ? { mixedContentMode: "always" as const } : {})}
        />
      </View>

      {activeCallUrl && (
        <View
          style={
            !callMinimized
              ? styles.callOverlayFullscreen
              : [
                  styles.callOverlayMinimizedBase,
                  styles.callOverlayMinimizedBottom,
                  { bottom: insets.bottom }
                ]
          }
        >
          <View style={[styles.callShell, callMinimized ? styles.callShellDocked : styles.callShellFullscreen]}>
            <View
              style={[
                styles.callHeader,
                callMinimized && styles.callHeaderDocked,
                {
                  backgroundColor: colors.surface,
                  borderBottomColor: colors.border,
                  paddingTop: callMinimized ? 6 : Math.max(insets.top + 8, 14)
                }
              ]}
            >
              <TouchableOpacity
                activeOpacity={0.7}
                disabled={!callMinimized}
                onPress={() => setCallMinimized(false)}
                style={callMinimized ? styles.callTitlePressable : undefined}
              >
                <Text style={[styles.callTitle, { color: colors.text }]}>Call in progress</Text>
              </TouchableOpacity>
              <View style={styles.callHeaderActions}>
                {callMinimized ? (
                  <TouchableOpacity
                    style={[styles.buttonSecondary, styles.callHeaderActionButton, { borderColor: colors.primary }]}
                    onPress={() => setCallMinimized(false)}
                  >
                    <Text style={[styles.buttonSecondaryLabel, { color: colors.primary }]}>Expand</Text>
                  </TouchableOpacity>
                ) : (
                  <TouchableOpacity
                    style={[styles.buttonSecondary, styles.callHeaderActionButton, { borderColor: colors.primary }]}
                    onPress={() => setCallMinimized(true)}
                  >
                    <Text style={[styles.buttonSecondaryLabel, { color: colors.primary }]}>Back to chat</Text>
                  </TouchableOpacity>
                )}
                <TouchableOpacity
                  style={[styles.buttonSecondary, styles.callHeaderActionButton, { borderColor: colors.border }]}
                  onPress={() => {
                    setActiveCallUrl(null);
                    setCallMinimized(false);
                  }}
                >
                  <Text style={[styles.buttonSecondaryLabel, { color: colors.text }]}>Leave</Text>
                </TouchableOpacity>
              </View>
            </View>
            <View style={callMinimized ? styles.callDockPreviewOuter : styles.callWebViewOuter}>
              <WebView
                style={callMinimized ? styles.callWebViewDockedInner : styles.callWebView}
                source={{ uri: activeCallUrl }}
                javaScriptEnabled
                domStorageEnabled
                mediaPlaybackRequiresUserAction={false}
                allowsInlineMediaPlayback
                allowsFullscreenVideo
                mediaCapturePermissionGrantType="grantIfSameHostElsePrompt"
                setSupportMultipleWindows={false}
                {...(Platform.OS === "android" ? { mixedContentMode: "always" as const } : {})}
              />
            </View>
          </View>
        </View>
      )}

      {incomingCall && !activeCallUrl && (
        <View style={styles.incomingCallOverlay}>
          <View style={[styles.incomingCallCard, { backgroundColor: colors.surface, borderColor: colors.border }]}>
            <Text style={[styles.incomingCallTitle, { color: colors.text }]}>{incomingCall.title}</Text>
            <Text style={[styles.incomingCallBody, { color: colors.subtext }]}>{incomingCall.body}</Text>
            <View style={styles.incomingCallActions}>
              <TouchableOpacity
                style={[styles.buttonSecondary, styles.incomingCallDeclineButton, { borderColor: colors.border }]}
                onPress={() => {
                  markIncomingCallDismissed(incomingCall);
                  setIncomingCall(null);
                }}
              >
                <Text style={[styles.buttonSecondaryLabel, { color: colors.text }]}>Dismiss</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.button, styles.incomingCallAcceptButton, { backgroundColor: colors.primary }]}
                onPress={() => {
                  const didOpen = tryOpenCallUrl(incomingCall.callUrl);
                  if (!didOpen && incomingCall.path) navigateWebViewToUrl(incomingCall.path);
                }}
              >
                <Text style={[styles.buttonLabel, { color: colors.primaryText }]}>Join now</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <AppContent />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f7f8fa"
  },
  center: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#f7f8fa"
  },
  card: {
    margin: 16,
    padding: 16,
    borderRadius: 12,
    backgroundColor: "#fff"
  },
  title: {
    fontSize: 22,
    fontWeight: "700",
    marginBottom: 8
  },
  helperText: {
    color: "#5a6270",
    marginBottom: 10
  },
  errorText: {
    fontSize: 13,
    marginBottom: 8
  },
  input: {
    borderWidth: 1,
    borderColor: "#d2d8e0",
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 10,
    backgroundColor: "#fff"
  },
  button: {
    backgroundColor: "#246bff",
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 12
  },
  buttonLabel: {
    color: "#fff",
    textAlign: "center",
    fontWeight: "600"
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#dfe3ea",
    backgroundColor: "#fff"
  },
  settingsHeader: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 12
  },
  brandWrap: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center"
  },
  brandTextWrap: {
    flex: 1
  },
  brandLogo: {
    width: 24,
    height: 24,
    borderRadius: 6,
    marginRight: 8
  },
  brandNameText: {
    fontSize: 13,
    fontWeight: "700",
    color: "#2f3440"
  },
  domainText: {
    flex: 1,
    fontSize: 11,
    color: "#5a6270"
  },
  topBarSettingsButton: {
    borderRadius: 999,
    backgroundColor: "#246bff",
    paddingHorizontal: 10,
    paddingVertical: 6,
    marginLeft: 8
  },
  topBarSettingsButtonLabel: {
    color: "#fff",
    fontSize: 11,
    fontWeight: "700"
  },
  floatingSettingsButton: {
    position: "absolute",
    right: 12,
    zIndex: 10,
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 6
  },
  floatingSettingsButtonLabel: {
    fontSize: 12,
    fontWeight: "700"
  },
  settingsCard: {
    maxHeight: 320,
    backgroundColor: "#fff",
    borderBottomWidth: 1,
    borderBottomColor: "#dfe3ea",
    paddingHorizontal: 14
  },
  settingsTitle: {
    fontSize: 18,
    fontWeight: "700",
    marginTop: 12,
    marginBottom: 10
  },
  label: {
    fontSize: 13,
    fontWeight: "600",
    marginTop: 8,
    marginBottom: 6
  },
  buttonSecondary: {
    borderColor: "#246bff",
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 8
  },
  buttonSecondaryLabel: {
    color: "#246bff",
    textAlign: "center",
    fontWeight: "600"
  },
  tokenText: {
    fontSize: 12,
    color: "#2f3440",
    marginBottom: 8
  },
  callOverlayFullscreen: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 20,
    backgroundColor: "#000"
  },
  /* Bottom strip; chat WebView gets matching paddingBottom so the composer sits above this */
  callOverlayMinimizedBase: {
    position: "absolute",
    left: 0,
    right: 0,
    zIndex: 20,
    height: MINIMIZED_CALL_DOCK_HEIGHT,
    backgroundColor: "#111",
    shadowColor: "#000",
    shadowOpacity: 0.25,
    shadowRadius: 6,
    elevation: 10
  },
  callOverlayMinimizedBottom: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "rgba(148, 163, 184, 0.35)",
    shadowOffset: { width: 0, height: -3 }
  },
  callShell: {
    flex: 1,
    flexDirection: "column",
    backgroundColor: "#000"
  },
  callShellFullscreen: {
    flex: 1
  },
  callShellDocked: {
    flex: 1,
    flexDirection: "row-reverse",
    alignItems: "stretch",
    backgroundColor: "#111"
  },
  callHeader: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderBottomWidth: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 8,
    flexWrap: "wrap"
  },
  callHeaderDocked: {
    flex: 1,
    minWidth: 0,
    paddingVertical: 6,
    paddingHorizontal: 8,
    borderBottomWidth: 0,
    flexWrap: "nowrap"
  },
  callHeaderActions: {
    flexDirection: "row",
    flexWrap: "wrap",
    alignItems: "center",
    justifyContent: "flex-end",
    gap: 8,
    flexShrink: 0
  },
  callHeaderActionButton: {
    marginBottom: 0,
    paddingVertical: 6,
    paddingHorizontal: 10
  },
  callTitlePressable: {
    flex: 1,
    minWidth: 120
  },
  callTitle: {
    fontSize: 14,
    fontWeight: "700"
  },
  callWebViewOuter: {
    flex: 1,
    minHeight: 200,
    backgroundColor: "#000"
  },
  callDockPreviewOuter: {
    width: 88,
    minHeight: 58,
    maxHeight: 58,
    alignSelf: "stretch",
    backgroundColor: "#000"
  },
  callWebView: {
    flex: 1,
    minHeight: 200,
    backgroundColor: "#000"
  },
  callWebViewDockedInner: {
    flex: 1,
    backgroundColor: "#000"
  },
  incomingCallOverlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 30,
    justifyContent: "flex-end",
    padding: 16,
    backgroundColor: "rgba(0,0,0,0.25)"
  },
  incomingCallCard: {
    borderWidth: 1,
    borderRadius: 14,
    padding: 14
  },
  incomingCallTitle: {
    fontSize: 17,
    fontWeight: "700",
    marginBottom: 4
  },
  incomingCallBody: {
    fontSize: 13,
    marginBottom: 12
  },
  incomingCallActions: {
    flexDirection: "row",
    gap: 10
  },
  incomingCallDeclineButton: {
    flex: 1,
    marginBottom: 0
  },
  incomingCallAcceptButton: {
    flex: 1
  },
  webviewWrap: {
    flex: 1,
    backgroundColor: "#000"
  },
  onboardingScroll: {
    paddingHorizontal: 20,
    paddingTop: 40,
    paddingBottom: 40,
    alignItems: "center"
  },
  onboardingLogo: {
    width: 72,
    height: 72,
    borderRadius: 16,
    marginBottom: 20
  },
  onboardingTitle: {
    fontSize: 26,
    fontWeight: "800",
    textAlign: "center",
    marginBottom: 8
  },
  onboardingSubtitle: {
    fontSize: 15,
    textAlign: "center",
    lineHeight: 22,
    marginBottom: 24,
    paddingHorizontal: 8
  },
  onboardingStepTitle: {
    fontSize: 17,
    fontWeight: "700",
    marginBottom: 10
  },
  onboardingStep: {
    fontSize: 14,
    lineHeight: 22,
    marginBottom: 6
  },
  onboardingLink: {
    fontSize: 14,
    fontWeight: "600",
    marginTop: 10
  }
});
