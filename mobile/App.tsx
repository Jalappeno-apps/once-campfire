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
  AppStateStatus,
  Image,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  Platform,
  View
} from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { WebView, WebViewMessageEvent } from "react-native-webview";

const APP_NAME = "Campfire";
const APP_LOGO = require("./logo.png");

const STORAGE_KEYS = {
  domain: "campfire.mobile.domain",
  pollPath: "campfire.mobile.pollPath",
  pollToken: "campfire.mobile.pollToken"
} as const;

const DEFAULT_POLL_PATH = "/api/mobile/notifications";
const POLL_INTERVAL_MS = 60_000;

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false
  })
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

function extractUnreadCount(payload: unknown): number | null {
  if (!payload) return null;
  if (typeof payload === "number") return payload;
  if (Array.isArray(payload)) return payload.length;
  if (typeof payload !== "object") return null;

  const record = payload as Record<string, unknown>;
  const directCount = record.unread_count;
  if (typeof directCount === "number") return directCount;

  if (Array.isArray(record.notifications)) return record.notifications.length;

  return null;
}

async function registerForPushTokenAsync(): Promise<string | null> {
  if (!Device.isDevice) return null;
  if (Constants.appOwnership === "expo") return null;

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
  const [loading, setLoading] = useState(true);
  const [domain, setDomain] = useState<string | null>(null);
  const [domainInput, setDomainInput] = useState("");
  const [pollPath, setPollPath] = useState(DEFAULT_POLL_PATH);
  const [pollToken, setPollToken] = useState("");
  const [showSettings, setShowSettings] = useState(false);
  const [authUserId, setAuthUserId] = useState<number | null>(null);
  const [pushToken, setPushToken] = useState<string | null>(null);
  const [pushRegistrationStatus, setPushRegistrationStatus] = useState("Waiting for sign-in");
  const [serverSupportsEmbeddedSettings, setServerSupportsEmbeddedSettings] = useState(false);

  const lastUnreadCountRef = useRef<number>(0);
  const appState = useRef<AppStateStatus>(AppState.currentState);

  const canPoll = useMemo(() => {
    return Boolean(domain && pollPath.trim().length > 0);
  }, [domain, pollPath]);

  const refreshAuthSession = useCallback(async () => {
    if (!domain) return;

    try {
      const response = await fetch(`${domain}/api/mobile/session`, {
        method: "GET",
        credentials: "include",
        headers: { Accept: "application/json" }
      });

      if (!response.ok) {
        setAuthUserId(null);
        return;
      }

      const payload = (await response.json()) as { user_id?: number };
      setAuthUserId(typeof payload.user_id === "number" ? payload.user_id : null);
    } catch {
      // Ignore transient network failures and keep current auth state.
    }
  }, [domain]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const [storedDomain, storedPath, storedToken] = await Promise.all([
        AsyncStorage.getItem(STORAGE_KEYS.domain),
        AsyncStorage.getItem(STORAGE_KEYS.pollPath),
        AsyncStorage.getItem(STORAGE_KEYS.pollToken)
      ]);

      if (!mounted) return;
      if (storedDomain) {
        setDomain(storedDomain);
        setDomainInput(storedDomain);
      }
      if (storedPath) setPollPath(storedPath);
      if (storedToken) setPollToken(storedToken);

      if (mounted) setLoading(false);
    })();

    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    const sub = AppState.addEventListener("change", (nextState) => {
      appState.current = nextState;
      if (nextState === "active") {
        void refreshAuthSession();
      }
    });
    return () => sub.remove();
  }, [refreshAuthSession]);

  useEffect(() => {
    if (!domain) return;
    void refreshAuthSession();
  }, [domain, refreshAuthSession]);

  useEffect(() => {
    if (!canPoll) return;

    let timer: ReturnType<typeof setInterval> | null = null;
    let cancelled = false;

    async function pollNotifications() {
      if (cancelled || appState.current !== "active" || !domain) return;
      const path = pollPath.startsWith("/") ? pollPath : `/${pollPath}`;
      const url = `${domain}${path}`;

      const headers: Record<string, string> = { Accept: "application/json" };
      if (pollToken.trim()) headers.Authorization = `Bearer ${pollToken.trim()}`;

      try {
        const response = await fetch(url, { method: "GET", headers });
        if (!response.ok) return;
        const payload = (await response.json()) as unknown;
        const unreadCount = extractUnreadCount(payload);
        if (unreadCount === null) return;

        const previous = lastUnreadCountRef.current;
        if (unreadCount > previous) {
          await Notifications.scheduleNotificationAsync({
            content: {
              title: "New Campfire activity",
              body: `You have ${unreadCount} unread notifications.`,
              data: { unreadCount }
            },
            trigger: null
          });
        }
        lastUnreadCountRef.current = unreadCount;
      } catch {
        // Ignore poll errors; this endpoint shape can vary by deployment.
      }
    }

    void pollNotifications();
    timer = setInterval(() => {
      void pollNotifications();
    }, POLL_INTERVAL_MS);

    return () => {
      cancelled = true;
      if (timer) clearInterval(timer);
    };
  }, [canPoll, domain, pollPath, pollToken]);

  useEffect(() => {
    if (!authUserId) {
      setPushRegistrationStatus("Sign in to enable push");
      return;
    }

    if (pushToken) return;

    let cancelled = false;

    async function ensurePushToken() {
      setPushRegistrationStatus("Requesting notification permission...");
      const token = await registerForPushTokenAsync();

      if (cancelled) return;

      if (token) {
        setPushToken(token);
        setPushRegistrationStatus("Token ready");
      } else {
        setPushRegistrationStatus("Permission denied or unavailable");
      }
    }

    void ensurePushToken();

    return () => {
      cancelled = true;
    };
  }, [authUserId, pushToken]);

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

    await AsyncStorage.setItem(STORAGE_KEYS.domain, normalized);
    setDomain(normalized);
    setShowSettings(false);
  }

  async function savePollingSettings() {
    await AsyncStorage.multiSet([
      [STORAGE_KEYS.pollPath, pollPath.trim() || DEFAULT_POLL_PATH],
      [STORAGE_KEYS.pollToken, pollToken.trim()]
    ]);
    Alert.alert("Saved", "Notification polling settings were saved.");
  }

  function handleWebViewMessage(event: WebViewMessageEvent) {
    try {
      const payload = JSON.parse(event.nativeEvent.data) as { type?: string; nativeSettingsSupported?: boolean };
      if (payload.type === "open-app-settings") {
        setShowSettings(true);
      } else if (payload.type === "close-app-settings") {
        setShowSettings(false);
      } else if (payload.type === "server-capabilities") {
        setServerSupportsEmbeddedSettings(Boolean(payload.nativeSettingsSupported));
      }
    } catch {
      // Ignore non-JSON bridge messages from webpages.
    }
  }

  function handleWebViewLoadEnd() {
    void refreshAuthSession();
  }

  if (loading) {
    return (
      <SafeAreaView edges={["top"]} style={styles.center}>
        <ActivityIndicator size="large" />
        <Text style={styles.helperText}>Preparing app...</Text>
      </SafeAreaView>
    );
  }

  if (!domain) {
    return (
      <SafeAreaView edges={["top"]} style={styles.container}>
        <StatusBar style="dark" />
        <View style={styles.card}>
          <Text style={styles.title}>Connect your Campfire</Text>
          <Text style={styles.helperText}>Enter the domain where Campfire is hosted.</Text>
          <TextInput
            value={domainInput}
            onChangeText={setDomainInput}
            placeholder="chat.example.com"
            autoCapitalize="none"
            autoCorrect={false}
            style={styles.input}
          />
          <TouchableOpacity style={styles.button} onPress={() => void saveDomain()}>
            <Text style={styles.buttonLabel}>Save and continue</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView edges={["top"]} style={styles.container}>
      <StatusBar style="dark" />
      <View style={styles.topBar}>
        <View style={styles.brandWrap}>
          <Image source={APP_LOGO} style={styles.brandLogo} />
          <View style={styles.brandTextWrap}>
            <Text style={styles.brandNameText}>{APP_NAME}</Text>
            <Text style={styles.domainText}>{domain}</Text>
          </View>
        </View>
        {!serverSupportsEmbeddedSettings && (
          <TouchableOpacity style={styles.topBarSettingsButton} onPress={() => setShowSettings((value) => !value)}>
            <Text style={styles.topBarSettingsButtonLabel}>{showSettings ? "Close settings" : "Server settings"}</Text>
          </TouchableOpacity>
        )}
      </View>

      {showSettings && (
        <ScrollView style={styles.settingsCard}>
          <Text style={styles.settingsTitle}>App settings</Text>

          <Text style={styles.label}>Campfire domain</Text>
          <TextInput
            value={domainInput || domain}
            onChangeText={setDomainInput}
            autoCapitalize="none"
            autoCorrect={false}
            style={styles.input}
          />
          <TouchableOpacity style={styles.buttonSecondary} onPress={() => void saveDomain()}>
            <Text style={styles.buttonSecondaryLabel}>Update domain</Text>
          </TouchableOpacity>

          <Text style={styles.label}>Notification poll path</Text>
          <TextInput
            value={pollPath}
            onChangeText={setPollPath}
            autoCapitalize="none"
            autoCorrect={false}
            style={styles.input}
            placeholder={DEFAULT_POLL_PATH}
          />
          <Text style={styles.helperText}>
            Endpoint should return unread count, notifications array, or number.
          </Text>

          <Text style={styles.label}>API token (optional)</Text>
          <TextInput
            value={pollToken}
            onChangeText={setPollToken}
            autoCapitalize="none"
            autoCorrect={false}
            style={styles.input}
            placeholder="Bearer token for poll endpoint"
          />

          <TouchableOpacity style={styles.buttonSecondary} onPress={() => void savePollingSettings()}>
            <Text style={styles.buttonSecondaryLabel}>Save notification settings</Text>
          </TouchableOpacity>

          <Text style={styles.label}>Device push token</Text>
          <Text style={styles.tokenText}>
            {pushToken ?? "Unavailable in Expo Go. Use a development build with EAS project id for remote push."}
          </Text>
          <Text style={styles.helperText}>Push registration: {pushRegistrationStatus}</Text>
          <Text style={styles.helperText}>
            Later, send this token to your backend/companion push service to deliver native push.
          </Text>
        </ScrollView>
      )}

      <View style={styles.webviewWrap}>
        <WebView
          source={{ uri: domain }}
          sharedCookiesEnabled
          thirdPartyCookiesEnabled
          userAgent="CampfireMobileApp/1.0"
          injectedJavaScriptBeforeContentLoaded={`
            window.__CAMPFIRE_NATIVE_APP__ = true;
            window.__CAMPFIRE_NATIVE_APP_PLATFORM__ = "react-native";
            window.__reportCampfireNativeCapabilities = function() {
              var supported = !!document.querySelector('meta[name="campfire-native-settings-supported"]');
              if (window.ReactNativeWebView && window.ReactNativeWebView.postMessage) {
                window.ReactNativeWebView.postMessage(JSON.stringify({
                  type: "server-capabilities",
                  nativeSettingsSupported: supported
                }));
              }
            };
            if (document.readyState === "loading") {
              document.addEventListener("DOMContentLoaded", window.__reportCampfireNativeCapabilities, { once: true });
            } else {
              window.__reportCampfireNativeCapabilities();
            }
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
            true;
          `}
          onMessage={handleWebViewMessage}
          onLoadEnd={handleWebViewLoadEnd}
        />
      </View>
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
  webviewWrap: {
    flex: 1,
    backgroundColor: "#fff"
  }
});
