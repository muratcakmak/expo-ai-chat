import { StatusBar } from "expo-status-bar";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  Platform,
  Animated,
  useWindowDimensions,
} from "react-native";
import {
  AiComposer,
  AiComposerWrapper,
  constants,
  type AiComposerRef,
} from "expo-ai-composer";

type Message = {
  id: string;
  text: string;
  role: "user" | "assistant";
};

const LONG_RESPONSE =
  "Here's a deliberately long streamed response for stress-testing scroll pinning, " +
  "keyboard transitions, and layout thrash under continuous content growth. We want to " +
  "confirm that when the user presses send, the keyboard dismiss animation and the " +
  "pin-to-top scroll feel like a single, consistent motion — not a snap down and then " +
  "a scroll up. While this message streams in word-by-word, watch for subtle jitter in " +
  "the pinned position: the content should remain visually anchored at the pinned offset " +
  "without fighting the user's scroll gestures. Also verify that the scroll-to-bottom " +
  "button logic stays stable (no flashing) and that scroll indicator insets don't jump " +
  "unexpectedly. If you rotate the device, change dynamic type size, or trigger safe-area " +
  "changes, the pinned behavior should remain predictable and shouldn't reset into a " +
  "broken state. Finally, confirm that the animation timing is consistent between the " +
  "2nd message and later messages — it should not feel like it speeds up as more messages " +
  "arrive; instead, each pin should feel smooth, predictable, and native.";

// First message animated wrapper — slides from bottom to top + fades in
function FirstMessageAnimated({
  children,
  isFirst,
  role,
}: {
  children: React.ReactNode;
  isFirst: boolean;
  role: "user" | "assistant";
}) {
  const { height: windowHeight } = useWindowDimensions();
  const translateY = useRef(new Animated.Value(isFirst && role === "user" ? windowHeight * 0.6 : 0)).current;
  const opacity = useRef(new Animated.Value(isFirst ? 0 : 1)).current;
  const didAnimate = useRef(false);

  useEffect(() => {
    if (!isFirst || didAnimate.current) return;
    didAnimate.current = true;

    if (role === "user") {
      // User message: slide from bottom to top + fade in
      Animated.parallel([
        Animated.spring(translateY, {
          toValue: 0,
          damping: 20,
          stiffness: 180,
          mass: 1,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      // Assistant message: fade in after a delay (staggered)
      Animated.timing(opacity, {
        toValue: 1,
        duration: 350,
        delay: 200,
        useNativeDriver: true,
      }).start();
    }
  }, [isFirst, role, translateY, opacity]);

  if (!isFirst) return <>{children}</>;

  return (
    <Animated.View style={{ transform: [{ translateY }], opacity }}>
      {children}
    </Animated.View>
  );
}

export default function App() {
  const composerRef = useRef<AiComposerRef>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [composerHeight, setComposerHeight] = useState(
    constants.defaultMinHeight
  );
  const [isStreaming, setIsStreaming] = useState(false);
  const streamingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const streamChunkTimeoutsRef = useRef<ReturnType<typeof setTimeout>[]>([]);
  const isFirstSend = useRef(true);

  const handleSend = useCallback((text: string) => {
    if (!text.trim()) return;

    // Clear any existing stream
    if (streamingTimeoutRef.current) {
      clearTimeout(streamingTimeoutRef.current);
      streamingTimeoutRef.current = null;
    }
    streamChunkTimeoutsRef.current.forEach((id) => clearTimeout(id));
    streamChunkTimeoutsRef.current = [];

    setIsStreaming(true);

    const wasFirst = isFirstSend.current;
    isFirstSend.current = false;

    const userMessage: Message = {
      id: Date.now().toString(),
      text: text.trim(),
      role: "user",
    };

    setMessages((prev) => [...prev, userMessage]);

    // Add empty assistant message after a delay
    const assistantId = (Date.now() + 1).toString();
    const assistantDelay = wasFirst ? 800 : 500; // longer delay for first to let user msg animate
    setTimeout(() => {
      setMessages((prev) => [
        ...prev,
        { id: assistantId, text: "", role: "assistant" },
      ]);
    }, assistantDelay);

    // Stream the response word by word
    const words = LONG_RESPONSE.split(" ");
    let currentText = "";
    const streamStartDelay = wasFirst ? 1200 : 600; // longer for first

    words.forEach((word, index) => {
      const timeoutId = setTimeout(() => {
        currentText += (index === 0 ? "" : " ") + word;
        const streamedText = currentText;
        setMessages((prev) =>
          prev.map((msg) =>
            msg.id === assistantId ? { ...msg, text: streamedText } : msg
          )
        );
      }, streamStartDelay + index * 50);
      streamChunkTimeoutsRef.current.push(timeoutId);
    });

    const totalDuration = streamStartDelay + words.length * 50 + 50;
    streamingTimeoutRef.current = setTimeout(() => {
      setIsStreaming(false);
      streamingTimeoutRef.current = null;
      streamChunkTimeoutsRef.current = [];
    }, totalDuration);
  }, []);

  const handleStop = useCallback(() => {
    if (streamingTimeoutRef.current) {
      clearTimeout(streamingTimeoutRef.current);
      streamingTimeoutRef.current = null;
    }
    streamChunkTimeoutsRef.current.forEach((id) => clearTimeout(id));
    streamChunkTimeoutsRef.current = [];
    setIsStreaming(false);
  }, []);

  const baseBottomInset = composerHeight;
  // Track which messages are part of the first exchange
  const firstUserMsgId = messages.find((m) => m.role === "user")?.id;
  const firstAssistantMsgId = messages.find((m) => m.role === "assistant")?.id;

  return (
    <View style={styles.container}>
      <StatusBar style="dark" />

      <View style={styles.header}>
        <Text style={styles.headerTitle}>AI Composer</Text>
        <Text style={styles.headerSubtitle}>
          Content-aware keyboard handling
        </Text>
      </View>

      <AiComposerWrapper
        style={styles.chatArea}
        pinToTopEnabled={true}
        extraBottomInset={baseBottomInset}
      >
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.messageList}
        >
          {messages.length === 0 && (
            <Text style={styles.placeholder}>
              Send a message to test the composer
            </Text>
          )}
          {messages.map((item) => {
            const isFirstUser = item.id === firstUserMsgId && messages.length <= 2;
            const isFirstAssistant = item.id === firstAssistantMsgId && messages.length <= 2;
            const isFirst = isFirstUser || isFirstAssistant;

            if (item.role === "user") {
              return (
                <FirstMessageAnimated key={item.id} isFirst={isFirst} role="user">
                  <View style={styles.userMessageContainer}>
                    <View style={styles.userBubble}>
                      <Text style={styles.userText}>{item.text}</Text>
                    </View>
                  </View>
                </FirstMessageAnimated>
              );
            }
            if (!item.text) {
              return (
                <FirstMessageAnimated key={item.id} isFirst={isFirst} role="assistant">
                  <View style={styles.assistantContainer}>
                    <Text style={styles.assistantText}>...</Text>
                  </View>
                </FirstMessageAnimated>
              );
            }
            return (
              <FirstMessageAnimated key={item.id} isFirst={isFirst} role="assistant">
                <View style={styles.assistantContainer}>
                  <Text style={styles.assistantText}>{item.text}</Text>
                </View>
              </FirstMessageAnimated>
            );
          })}
        </ScrollView>

        <View
          style={[styles.composerContainer, { height: composerHeight }]}
          pointerEvents="box-none"
        >
          <View style={styles.composerInner} pointerEvents="box-none">
            <View style={styles.composerWrapper}>
              <AiComposer
                ref={composerRef}
                style={{ flex: 1 }}
                placeholder="Ask anything"
                onSend={handleSend}
                onStop={handleStop}
                onHeightChange={setComposerHeight}
                minHeight={constants.defaultMinHeight}
                maxHeight={constants.defaultMaxHeight}
                sendButtonEnabled
                isStreaming={isStreaming}
              />
            </View>
          </View>
        </View>
      </AiComposerWrapper>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#ffffff",
  },
  header: {
    paddingTop: Platform.OS === "ios" ? 60 : 40,
    paddingHorizontal: 16,
    paddingBottom: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#e5e5e5",
  },
  headerTitle: {
    fontWeight: "600",
    fontSize: 17,
    textAlign: "center",
    color: "#000",
  },
  headerSubtitle: {
    fontSize: 12,
    textAlign: "center",
    color: "#8e8e93",
    marginTop: 2,
  },
  chatArea: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  messageList: {
    paddingHorizontal: 16,
    paddingTop: 16,
  },
  placeholder: {
    color: "#999",
    textAlign: "center",
    marginTop: 200,
    fontSize: 16,
  },
  userMessageContainer: {
    marginBottom: 32,
    alignItems: "flex-end",
  },
  userBubble: {
    maxWidth: "80%",
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 20,
    backgroundColor: "#F4F4F4",
  },
  userText: {
    color: "#000",
    fontSize: 16,
    lineHeight: 22,
  },
  assistantContainer: {
    marginBottom: 32,
    alignItems: "flex-start",
  },
  assistantText: {
    color: "#000",
    fontSize: 16,
    lineHeight: 22,
  },
  composerContainer: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
  },
  composerInner: {
    paddingHorizontal: 16,
    flex: 1,
  },
  composerWrapper: {
    borderRadius: 24,
    overflow: "hidden",
    backgroundColor: "#F2F2F7",
    flex: 1,
  },
});
