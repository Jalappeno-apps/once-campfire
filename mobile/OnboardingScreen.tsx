import React, { useCallback, useRef, useState } from "react";
import {
  ActivityIndicator,
  Dimensions,
  FlatList,
  Image,
  KeyboardAvoidingView,
  Linking,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  ViewToken,
  useColorScheme,
} from "react-native";

const { width: SCREEN_WIDTH } = Dimensions.get("window");
const APP_LOGO = require("./logo.png");

/* Simple filled icons matching web app SVG style */
function MessagesIcon({ color }: { color: string }) {
  // Matches messages.svg: speech bubble path
  return (
    <View style={[iconStyle.wrap, { backgroundColor: color + "15" }]}>
      <View style={[iconStyle.bubble, { borderColor: color }]}>
        <View style={[iconStyle.bubbleInner, { backgroundColor: color }]} />
      </View>
    </View>
  );
}

function ServerIcon({ color }: { color: string }) {
  return (
    <View style={[iconStyle.wrap, { backgroundColor: color + "15" }]}>
      {[0, 1, 2].map((i) => (
        <View key={i} style={[iconStyle.serverLine, { backgroundColor: color, top: 14 + i * 10 }]} />
      ))}
    </View>
  );
}

function LinkIcon({ color }: { color: string }) {
  return (
    <View style={[iconStyle.wrap, { backgroundColor: color + "15" }]}>
      <View style={[iconStyle.linkLine, { backgroundColor: color }]} />
      <View style={[iconStyle.linkCircleLeft, { borderColor: color }]} />
      <View style={[iconStyle.linkCircleRight, { borderColor: color }]} />
    </View>
  );
}

const iconStyle = StyleSheet.create({
  wrap: { 
    width: 64, 
    height: 64, 
    borderRadius: 16, 
    alignItems: "center", 
    justifyContent: "center",
    marginBottom: 24 
  },
  bubble: {
    width: 36,
    height: 28,
    borderRadius: 12,
    borderWidth: 2,
    alignItems: "center",
    justifyContent: "center",
  },
  bubbleInner: {
    width: 24,
    height: 16,
    borderRadius: 6,
  },
  serverLine: {
    position: "absolute",
    left: 18,
    width: 28,
    height: 4,
    borderRadius: 2,
  },
  linkLine: {
    position: "absolute",
    width: 24,
    height: 3,
    borderRadius: 2,
    transform: [{ rotate: "-30deg" }],
  },
  linkCircleLeft: {
    position: "absolute",
    left: 16,
    width: 10,
    height: 10,
    borderRadius: 5,
    borderWidth: 2,
    backgroundColor: "transparent",
  },
  linkCircleRight: {
    position: "absolute",
    right: 16,
    width: 10,
    height: 10,
    borderRadius: 5,
    borderWidth: 2,
    backgroundColor: "transparent",
  },
});

interface OnboardingScreenProps {
  domainInput: string;
  onDomainInputChange: (text: string) => void;
  onConnect: () => void;
}

type SlideType = "hero" | "info" | "deploy" | "connect";

interface SlideData {
  key: string;
  type: SlideType;
  icon?: React.ReactNode;
  title: string;
  body: string;
}

const SLIDES: SlideData[] = [
  {
    key: "hero",
    type: "hero",
    title: "Campfire",
    body: "Group chat for friends, clubs, communities, and crews.",
  },
  {
    key: "how",
    type: "info",
    icon: <MessagesIcon color="#246bff" />,
    title: "Join a community",
    body: "Anyone can create a Campfire and invite others. Download the app, join with a link, and start chatting.",
  },
  {
    key: "deploy",
    type: "deploy",
    icon: <ServerIcon color="#5856D6" />,
    title: "Host your own",
    body: "Deploy on Railway in one click, or host it yourself. Free and open source.",
  },
  {
    key: "connect",
    type: "connect",
    icon: <LinkIcon color="#34C759" />,
    title: "Connect",
    body: "Enter a Campfire address to join.",
  },
];

const TOTAL = SLIDES.length;

export default function OnboardingScreen({
  domainInput,
  onDomainInputChange,
  onConnect,
}: OnboardingScreenProps) {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === "dark";
  
  // Match web app colors exactly (OKLCH approximated to hex)
  const C = isDark
    ? {
        bg: "#000000",
        text: "#ffffff",
        sub: "#8a8a8a",
        accent: "#4a9eff",  // lighter blue for dark
        accentSoft: "#1a1a1a",
        border: "#333333",
        inputBg: "#111111",
        dot: "#444444",
        dotActive: "#ffffff",  // white active dot in dark mode
      }
    : {
        bg: "#ffffff",
        text: "#000000",
        sub: "#666666",
        accent: "#246bff",
        accentSoft: "#f5f5f5",
        border: "#e5e5e5",
        inputBg: "#ffffff",
        dot: "#d0d0d0",
        dotActive: "#000000",  // black active dot in light mode
      };

  const [activeIndex, setActiveIndex] = useState(0);
  const [connecting, setConnecting] = useState(false);
  const flatListRef = useRef<FlatList>(null);

  const onViewableItemsChanged = useRef(
    ({ viewableItems }: { viewableItems: ViewToken[] }) => {
      const first = viewableItems[0];
      if (first && first.index != null) setActiveIndex(first.index);
    }
  ).current;
  
  const viewabilityConfig = useRef({ viewAreaCoveragePercentThreshold: 50 }).current;

  const goToNext = useCallback(() => {
    if (activeIndex < TOTAL - 1) {
      flatListRef.current?.scrollToIndex({ index: activeIndex + 1, animated: true });
    }
  }, [activeIndex]);

  const goToSlide = useCallback((i: number) => {
    flatListRef.current?.scrollToIndex({ index: i, animated: true });
  }, []);

  const handleConnect = useCallback(() => {
    if (!domainInput.trim()) return;
    setConnecting(true);
    onConnect();
  }, [domainInput, onConnect]);

  const isLast = activeIndex === TOTAL - 1;

  const onBottomButtonPress = () => {
    if (isLast) handleConnect();
    else goToNext();
  };

  const bottomButtonDisabled = isLast && (!domainInput.trim() || connecting);
  const bottomButtonText = isLast ? "Connect" : activeIndex === 0 ? "Get Started" : "Next";

  const renderHero = () => (
    <View style={[s.slide, { width: SCREEN_WIDTH }]}>
      <View style={s.heroCenter}>
        <Image source={APP_LOGO} style={s.heroLogo} />
        <Text style={[s.heroTitle, { color: C.text }]}>Campfire</Text>
        <Text style={[s.heroSub, { color: C.sub }]}>
          Group chat for friends, clubs,{"\n"}communities, and crews.
        </Text>
      </View>
    </View>
  );

  const renderSlide = useCallback(
    ({ item }: { item: SlideData }) => {
      if (item.type === "hero") return renderHero();

      return (
        <View style={[s.slide, { width: SCREEN_WIDTH }]}>
          <View style={s.slideContent}>
            {item.icon}
            <Text style={[s.title, { color: C.text }]}>{item.title}</Text>
            <Text style={[s.body, { color: C.sub }]}>{item.body}</Text>

            {item.type === "connect" && (
              <KeyboardAvoidingView
                behavior={Platform.OS === "ios" ? "padding" : undefined}
                style={s.connectSection}
              >
                <TextInput
                  value={domainInput}
                  onChangeText={onDomainInputChange}
                  placeholder="chat.example.com"
                  placeholderTextColor={C.sub}
                  autoCapitalize="none"
                  autoCorrect={false}
                  keyboardType="url"
                  returnKeyType="go"
                  onSubmitEditing={handleConnect}
                  editable={!connecting}
                  style={[s.input, { 
                    borderColor: C.border, 
                    backgroundColor: C.inputBg, 
                    color: C.text 
                  }]}
                />
              </KeyboardAvoidingView>
            )}

            {item.type === "deploy" && (
              <View style={s.extraSection}>
                <TouchableOpacity
                  onPress={() => void Linking.openURL("https://railway.com/deploy/campfire-1")}
                  activeOpacity={0.7}
                >
                  <Text style={[s.textLink, { color: C.accent }]}>Deploy on Railway →</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>
        </View>
      );
    },
    [C, domainInput, onDomainInputChange, handleConnect, connecting]
  );

  return (
    <View style={[s.container, { backgroundColor: C.bg }]}>
      <FlatList
        ref={flatListRef}
        data={SLIDES}
        renderItem={renderSlide}
        keyExtractor={(item) => item.key}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        bounces={false}
        onViewableItemsChanged={onViewableItemsChanged}
        viewabilityConfig={viewabilityConfig}
        getItemLayout={(_, index) => ({ 
          length: SCREEN_WIDTH, 
          offset: SCREEN_WIDTH * index, 
          index 
        })}
      />

      <View style={s.bottomBar}>
        <View style={s.dots}>
          {SLIDES.map((slide, i) => (
            <TouchableOpacity 
              key={slide.key} 
              onPress={() => goToSlide(i)} 
              activeOpacity={0.7}
            >
              <View style={[
                s.dot, 
                { 
                  backgroundColor: i === activeIndex ? C.dotActive : C.dot,
                  width: i === activeIndex ? 20 : 8,
                }
              ]} />
            </TouchableOpacity>
          ))}
        </View>

        <TouchableOpacity
          style={[
            s.bottomBtn, 
            { 
              backgroundColor: isDark ? (bottomButtonDisabled ? C.border : C.text) : (bottomButtonDisabled ? C.border : C.text),
            }
          ]}
          onPress={onBottomButtonPress}
          activeOpacity={0.7}
          disabled={bottomButtonDisabled}
        >
          {connecting ? (
            <ActivityIndicator color={isDark ? C.bg : C.bg} size="small" />
          ) : (
            <Text style={[s.bottomBtnText, { color: isDark ? C.bg : C.bg }]}>
              {bottomButtonText}
            </Text>
          )}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  container: { flex: 1 },

  slide: { 
    flex: 1, 
    justifyContent: "center", 
    alignItems: "center", 
    paddingHorizontal: 32 
  },
  slideContent: { 
    alignItems: "center", 
    width: "100%", 
    maxWidth: 340 
  },

  // Hero - clean, no effects
  heroCenter: { 
    flex: 1, 
    alignItems: "center", 
    justifyContent: "center", 
    width: "100%" 
  },
  heroLogo: { 
    width: 80, 
    height: 80, 
    borderRadius: 20, 
    marginBottom: 24 
  },
  heroTitle: { 
    fontSize: 32, 
    fontWeight: "700", 
    marginBottom: 8,
    letterSpacing: -0.5,
  },
  heroSub: { 
    fontSize: 16, 
    lineHeight: 24, 
    textAlign: "center" 
  },

  // Info slides
  title: { 
    fontSize: 22, 
    fontWeight: "600", 
    textAlign: "center", 
    marginBottom: 12 
  },
  body: { 
    fontSize: 15, 
    lineHeight: 22, 
    textAlign: "center" 
  },
  extraSection: { 
    marginTop: 24 
  },
  textLink: { 
    fontSize: 15, 
    fontWeight: "500",
  },

  // Connect
  connectSection: { 
    marginTop: 24, 
    width: "100%" 
  },
  input: { 
    borderWidth: 1, 
    borderRadius: 10, 
    paddingHorizontal: 16, 
    paddingVertical: 12, 
    fontSize: 16,
  },

  // Bottom - consistent
  bottomBar: { 
    alignItems: "center", 
    paddingBottom: 40, 
    paddingTop: 8, 
    gap: 16 
  },
  dots: { 
    flexDirection: "row", 
    alignItems: "center", 
    gap: 8 
  },
  dot: { 
    height: 8, 
    borderRadius: 4 
  },
  bottomBtn: { 
    paddingVertical: 14, 
    paddingHorizontal: 32, 
    borderRadius: 24,  // pill shape like web app
    minWidth: 160, 
    alignItems: "center",
  },
  bottomBtnText: { 
    fontSize: 16, 
    fontWeight: "600",
  },
});
