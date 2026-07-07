import { StatusBar } from "expo-status-bar";
import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  Platform,
  Animated,
  TouchableOpacity,
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

// Stress config: fast, high-frequency token emission over a large body so the streaming
// setState path is genuinely hammered (worst case for re-render cost).
const STREAM_INTERVAL_MS = 16; // ~1 flush per frame
const WORDS_PER_TICK = 2;
const STREAM_BODY = Array(4).fill(LONG_RESPONSE).join(" "); // ~4x longer per message
const STREAM_WORDS = STREAM_BODY.split(" ");
const STREAM_TICKS = Math.ceil(STREAM_WORDS.length / WORDS_PER_TICK);
const STRESS_BURST_COUNT = 6; // messages auto-fired back-to-back by the stress runner

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

// Memoized so a streaming setState only re-renders the one row whose text changed,
// not every message in the list.
const MessageRow = memo(function MessageRow({
  text,
  role,
  isFirst,
}: {
  text: string;
  role: "user" | "assistant";
  isFirst: boolean;
}) {
  if (role === "user") {
    return (
      <FirstMessageAnimated isFirst={isFirst} role="user">
        <View style={styles.userMessageContainer}>
          <View style={styles.userBubble}>
            <Text style={styles.userText}>{text}</Text>
          </View>
        </View>
      </FirstMessageAnimated>
    );
  }
  return (
    <FirstMessageAnimated isFirst={isFirst} role="assistant">
      <View style={styles.assistantContainer}>
        <Text style={styles.assistantText}>{text || "..."}</Text>
      </View>
    </FirstMessageAnimated>
  );
});

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
    const assistantDelay = wasFirst ? 800 : 400; // longer delay for first to let user msg animate
    setTimeout(() => {
      setMessages((prev) => [
        ...prev,
        { id: assistantId, text: "", role: "assistant" },
      ]);
    }, assistantDelay);

    // Stream the (large) body in fast multi-word ticks.
    let currentText = "";
    const streamStartDelay = wasFirst ? 1200 : 500; // longer for first

    for (let tick = 0; tick < STREAM_TICKS; tick++) {
      const timeoutId = setTimeout(() => {
        const slice = STREAM_WORDS.slice(
          tick * WORDS_PER_TICK,
          tick * WORDS_PER_TICK + WORDS_PER_TICK
        ).join(" ");
        currentText += (tick === 0 ? "" : " ") + slice;
        const streamedText = currentText;
        setMessages((prev) =>
          prev.map((msg) =>
            msg.id === assistantId ? { ...msg, text: streamedText } : msg
          )
        );
      }, streamStartDelay + tick * STREAM_INTERVAL_MS);
      streamChunkTimeoutsRef.current.push(timeoutId);
    }

    const totalDuration = streamStartDelay + STREAM_TICKS * STREAM_INTERVAL_MS + 50;
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

  // Auto-fire a burst of messages back-to-back, each spaced so its full stream lands
  // before the next — grows the list under sustained fast streaming (the worst case).
  const stressTimeoutsRef = useRef<ReturnType<typeof setTimeout>[]>([]);
  const runStressTest = useCallback(() => {
    stressTimeoutsRef.current.forEach((id) => clearTimeout(id));
    stressTimeoutsRef.current = [];
    const perMessageMs = STREAM_TICKS * STREAM_INTERVAL_MS + 1400;
    for (let i = 0; i < STRESS_BURST_COUNT; i++) {
      const id = setTimeout(() => {
        handleSend(`Stress message ${i + 1} of ${STRESS_BURST_COUNT}`);
      }, i * perMessageMs);
      stressTimeoutsRef.current.push(id);
    }
  }, [handleSend]);

  useEffect(() => {
    return () => {
      stressTimeoutsRef.current.forEach((id) => clearTimeout(id));
      streamChunkTimeoutsRef.current.forEach((id) => clearTimeout(id));
      if (streamingTimeoutRef.current) clearTimeout(streamingTimeoutRef.current);
    };
  }, []);

  // Rebuild only when messages change — not on composer-height or isStreaming changes.
  const messageList = useMemo(() => {
    const firstUserMsgId = messages.find((m) => m.role === "user")?.id;
    const firstAssistantMsgId = messages.find((m) => m.role === "assistant")?.id;
    return messages.map((item) => {
      const isFirst =
        (item.id === firstUserMsgId || item.id === firstAssistantMsgId) &&
        messages.length <= 2;
      return (
        <MessageRow
          key={item.id}
          text={item.text}
          role={item.role}
          isFirst={isFirst}
        />
      );
    });
  }, [messages]);

  return (
    <View style={styles.container}>
      <StatusBar style="dark" />

      <View style={styles.header}>
        <Text style={styles.headerTitle}>AI Composer</Text>
        <Text style={styles.headerSubtitle}>
          Content-aware keyboard handling
        </Text>
        <TouchableOpacity
          style={styles.stressButton}
          onPress={runStressTest}
          disabled={isStreaming}
        >
          <Text style={styles.stressButtonText}>
            Run stress ×{STRESS_BURST_COUNT}
          </Text>
        </TouchableOpacity>
      </View>

      <AiComposerWrapper
        style={styles.chatArea}
        pinToTopEnabled={true}
        extraBottomInset={composerHeight}
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
          {messageList}
        </ScrollView>

        <View
          style={[styles.composerContainer, { height: composerHeight }]}
          pointerEvents="box-none"
        >
          <View style={styles.composerInner} pointerEvents="box-none">
            <View style={styles.composerWrapper}>
              <AiComposer
                ref={composerRef}
                style={styles.composerFlex}
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
  composerFlex: {
    flex: 1,
  },
  stressButton: {
    position: "absolute",
    right: 16,
    bottom: 10,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 14,
    backgroundColor: "#111",
  },
  stressButtonText: {
    color: "#fff",
    fontSize: 12,
    fontWeight: "600",
  },
});
