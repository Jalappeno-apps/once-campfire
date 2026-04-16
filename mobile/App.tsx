import AsyncStorage from "@react-native-async-storage/async-storage";
import Constants from "expo-constants";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { StatusBar } from "expo-status-bar";
import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  AppState,
  Image,
  Linking,
  useColorScheme,
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

async function registerForPushTokenAsync(): Promise<string | null> {
  if (!Device.isDevice) return null;
  if (Constants.appOwnership === "expo") return null;

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("default", {
      name: "default",
      importance: Notifications.AndroidImportance.MAX
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
  const shouldShowServerButton = useMemo(() => {
    return !showSettings && isSettingsLikePath(currentWebUrl);
  }, [showSettings, currentWebUrl]);

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
      const storedDomain = await AsyncStorage.getItem(STORAGE_KEYS.domain);

      if (!mounted) return;
      if (storedDomain) {
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
    const sub = AppState.addEventListener("change", (nextState) => {
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
        <View style={[styles.card, { backgroundColor: colors.surface }]}>
          <Text style={[styles.title, { color: colors.text }]}>Connect your Campfire</Text>
          <Text style={[styles.helperText, { color: colors.subtext }]}>Enter the domain where Campfire is hosted.</Text>
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
            <Text style={[styles.buttonLabel, { color: colors.primaryText }]}>Save and continue</Text>
          </TouchableOpacity>
        </View>
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
            { bottom: Math.max(insets.bottom + 16, 24), backgroundColor: colors.surface, borderColor: colors.border }
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

      <View style={[styles.webviewWrap, { backgroundColor: colors.background }]}>
        <WebView
          source={{ uri: domain }}
          sharedCookiesEnabled
          thirdPartyCookiesEnabled
          userAgent="CampfireMobileApp/1.0"
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
            true;
          `}
          onMessage={handleWebViewMessage}
          onNavigationStateChange={(navState) => setCurrentWebUrl(navState.url)}
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
  webviewWrap: {
    flex: 1,
    backgroundColor: "#fff"
  }
});
