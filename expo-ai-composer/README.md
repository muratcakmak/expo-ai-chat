# expo-ai-composer

A native keyboard-aware AI composer component for React Native. Provides smooth, system-level keyboard animations and a ChatGPT-style pin-to-top scroll experience for chat UIs.

<table>
<tr>
<td width="50%" align="center">
<video src="https://github.com/muratcakmak/expo-ai-chat/raw/main/expo-ai-composer/assets/demo-1.mp4" width="280" controls></video>
<br/><b>First message animation + streaming</b>
</td>
<td width="50%" align="center">
<video src="https://github.com/muratcakmak/expo-ai-chat/raw/main/expo-ai-composer/assets/demo-2.mp4" width="280" controls></video>
<br/><b>Pin-to-top + keyboard handling</b>
</td>
</tr>
</table>

## Highlights

<table>
<tr>
<td width="50%">

### Keyboard Tracking
Native keyboard animations that match system apps like iMessage. No JS bridge lag.

</td>
<td width="50%">

### Pin-to-Top Scroll
New messages pin to the top of the viewport. Streaming responses grow below with a runway — no jarring scroll jumps.

</td>
</tr>
<tr>
<td width="50%">

### First Message Animation
The first message slides from the composer to the top of the screen with a spring animation, just like ChatGPT and v0.

</td>
<td width="50%">

### Streaming + Stop
Built-in send/stop button with haptic feedback. The stop button appears during streaming with a single prop toggle.

</td>
</tr>
</table>

## Features

- **Native keyboard tracking** — pixel-perfect animations using iOS keyboard notifications and Android `WindowInsetsAnimationCompat`
- **Pin-to-top scroll** — ChatGPT-style: user message pins to top, response streams below with runway inset
- **First message animation** — native pin automatically skips the first send so you can implement a slide-from-bottom animation in JS
- **Auto-growing text input** — multiline input that grows between configurable `minHeight` and `maxHeight`
- **Send/Stop button** — built-in circular send arrow and square stop icon with haptic feedback
- **Scroll-to-bottom FAB** — floating button appears when scrolled away, animates in sync with keyboard
- **Customizable accessory slots** — `headerAccessory`, `leadingAccessory`, `trailingAccessory`, `footerAccessory`
- **Transparent background** — no hardcoded colors; style from React Native
- **Expanded editor** — full-screen text editor sheet when maxHeight is reached (iOS)
- **Imperative ref** — `focus()`, `blur()`, `clear()` via React ref
- **Cross-platform** — full native implementations on both iOS and Android

## Installation

```bash
npx expo install expo-ai-composer
```

Requires Expo SDK 55+ with the [Expo Modules](https://docs.expo.dev/modules/overview/) system.

## Quick Start

```tsx
import { useState } from "react";
import { View, ScrollView } from "react-native";
import { AiComposer, AiComposerWrapper, constants } from "expo-ai-composer";

export default function ChatScreen() {
  const [composerHeight, setComposerHeight] = useState(constants.defaultMinHeight);
  const [isStreaming, setIsStreaming] = useState(false);

  const handleSend = (text: string) => {
    // Add user message, start streaming AI response...
    setIsStreaming(true);
  };

  return (
    <View style={{ flex: 1 }}>
      <AiComposerWrapper
        style={{ flex: 1 }}
        pinToTopEnabled
        extraBottomInset={composerHeight}
      >
        <ScrollView style={{ flex: 1 }}>
          {/* Your chat messages */}
        </ScrollView>

        <View style={{
          position: "absolute",
          bottom: 0, left: 0, right: 0,
          height: composerHeight,
        }}>
          <AiComposer
            style={{ flex: 1 }}
            placeholder="Ask anything"
            onSend={handleSend}
            onStop={() => setIsStreaming(false)}
            onHeightChange={setComposerHeight}
            isStreaming={isStreaming}
            sendButtonEnabled
          />
        </View>
      </AiComposerWrapper>
    </View>
  );
}
```

## API Reference

### `<AiComposer />`

The native text input with send/stop button.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `placeholder` | `string` | `"Type a message..."` | Placeholder text |
| `text` | `string` | — | Controlled text value |
| `minHeight` | `number` | `48` | Minimum composer height (points/dp) |
| `maxHeight` | `number` | `120` | Maximum height before scrolling |
| `sendButtonEnabled` | `boolean` | `true` | Whether send button is enabled |
| `showSendButton` | `boolean` | `true` | Show/hide the send button entirely |
| `editable` | `boolean` | `true` | Whether input is editable |
| `autoFocus` | `boolean` | `false` | Focus input on mount |
| `isStreaming` | `boolean` | `false` | Show stop button instead of send |
| `expandedEditorEnabled` | `boolean` | `false` | Enable full-screen editor (iOS only) |

#### Callbacks

| Callback | Type | Description |
|----------|------|-------------|
| `onChangeText` | `(text: string) => void` | Text changed |
| `onSend` | `(text: string) => void` | Send button pressed |
| `onStop` | `() => void` | Stop button pressed |
| `onHeightChange` | `(height: number) => void` | Composer height changed (for `extraBottomInset`) |
| `onKeyboardHeightChange` | `(height: number) => void` | Keyboard height changed |
| `onComposerFocus` | `() => void` | Input gained focus |
| `onComposerBlur` | `() => void` | Input lost focus |

#### Accessory Slots

Customize the area around the native text input with React Native views:

```tsx
<AiComposer
  headerAccessory={<FormattingToolbar />}
  leadingAccessory={<AttachmentButton />}
  trailingAccessory={<CustomSendButton />}
  footerAccessory={<ModelSelector />}
/>
```

| Slot | Position | Notes |
|------|----------|-------|
| `headerAccessory` | Above the input row | Formatting toolbar, context chips |
| `leadingAccessory` | Left of the input | Attachment, camera, mic button |
| `trailingAccessory` | Right of the input | **Replaces** built-in send button |
| `footerAccessory` | Below the input row | Model selector, file previews |

<!-- TODO: Replace with actual screenshot -->
<!-- ![Accessory Slots](./assets/slots-diagram.png) -->

```
┌─────────────────────────────────┐
│        headerAccessory          │
├──────┬──────────────────┬───────┤
│lead- │                  │trail- │
│ing   │   Native Input   │ing    │
│      │                  │       │
├──────┴──────────────────┴───────┤
│        footerAccessory          │
└─────────────────────────────────┘
```

#### Ref Methods

```tsx
import { useRef } from "react";
import { AiComposer, type AiComposerRef } from "expo-ai-composer";

const composerRef = useRef<AiComposerRef>(null);

// Programmatic control
composerRef.current?.focus();  // Focus the input
composerRef.current?.blur();   // Blur the input
composerRef.current?.clear();  // Clear all text

<AiComposer ref={composerRef} ... />
```

---

### `<AiComposerWrapper />`

Keyboard-aware container that manages scroll position, keyboard animations, and composer translation. Wrap your `ScrollView` and `AiComposer` together inside this component.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `pinToTopEnabled` | `boolean` | `false` | Enable ChatGPT-style pin-to-top on send |
| `extraBottomInset` | `number` | `0` | Composer height — pass from `onHeightChange` |
| `extraTopInset` | `number` | `0` | Extra top inset for transparent headers (Android) |
| `scrollToTopTrigger` | `number` | `0` | Manually trigger pin (use `Date.now()` or counter) |
| `children` | `ReactNode` | — | Must contain a ScrollView and the composer |
| `style` | `ViewStyle` | — | Container style |

#### Keyboard Behavior

| Scenario | Behavior |
|----------|----------|
| Keyboard opens while at bottom | Auto-scrolls to keep content visible |
| Keyboard opens while mid-scroll | Opens over content, no scroll change |
| User sends message (2nd+) | Message pins to top, response streams below |
| User sends first message | Native pin skipped — implement JS animation |
| User scrolls away from bottom | Scroll-to-bottom FAB appears |
| User drags scroll view down quickly | Keyboard dismisses (interactive) |

---

### `constants`

Native constants exported from the module:

```tsx
import { constants } from "expo-ai-composer";

constants.defaultMinHeight; // 48  — default minimum composer height
constants.defaultMaxHeight; // 120 — default maximum composer height
constants.contentGap;       // 0   — gap between content and composer
```

## Layout Guide

### Recommended Structure

```tsx
<View style={{ flex: 1 }}>
  {/* Optional: Header above the wrapper */}
  <Header />

  <AiComposerWrapper
    style={{ flex: 1 }}
    pinToTopEnabled
    extraBottomInset={composerHeight}
  >
    {/* ScrollView fills available space */}
    <ScrollView
      style={{ flex: 1 }}
      contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 16 }}
    >
      {messages.map(renderMessage)}
    </ScrollView>

    {/* Composer is absolutely positioned — native code handles translation */}
    <View
      style={{
        position: "absolute",
        bottom: 0, left: 0, right: 0,
        height: composerHeight,
      }}
      pointerEvents="box-none"
    >
      <View style={{ paddingHorizontal: 16, flex: 1 }}>
        <View style={{
          borderRadius: 24,
          overflow: "hidden",
          backgroundColor: "#F2F2F7",
          flex: 1,
        }}>
          <AiComposer
            style={{ flex: 1 }}
            placeholder="Ask anything"
            onSend={handleSend}
            onStop={handleStop}
            onHeightChange={setComposerHeight}
            minHeight={constants.defaultMinHeight}
            maxHeight={constants.defaultMaxHeight}
            isStreaming={isStreaming}
            sendButtonEnabled
          />
        </View>
      </View>
    </View>
  </AiComposerWrapper>
</View>
```

### Important Layout Rules

1. **No `paddingBottom` on scroll content** — the native wrapper handles bottom spacing via `extraBottomInset`
2. **Composer uses `height: composerHeight`** — track via `onHeightChange` callback
3. **Safe area is handled natively** — don't wrap the composer in `SafeAreaView`
4. **Use `pointerEvents="box-none"`** on the composer container to allow scroll touches to pass through

## First Message Animation

The native pin-to-top automatically skips the first send. This lets you implement a smooth slide-from-bottom animation in JavaScript:

```tsx
import { useRef, useEffect } from "react";
import { Animated, useWindowDimensions } from "react-native";

function FirstMessageAnimated({
  children,
  isFirst,
  role,
}: {
  children: React.ReactNode;
  isFirst: boolean;
  role: "user" | "assistant";
}) {
  const { height } = useWindowDimensions();
  const translateY = useRef(
    new Animated.Value(isFirst && role === "user" ? height * 0.6 : 0)
  ).current;
  const opacity = useRef(new Animated.Value(isFirst ? 0 : 1)).current;

  useEffect(() => {
    if (!isFirst) return;

    if (role === "user") {
      // Slide from bottom to top + fade in
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
      // Assistant: staggered fade in
      Animated.timing(opacity, {
        toValue: 1,
        duration: 350,
        delay: 200,
        useNativeDriver: true,
      }).start();
    }
  }, []);

  if (!isFirst) return <>{children}</>;

  return (
    <Animated.View style={{ transform: [{ translateY }], opacity }}>
      {children}
    </Animated.View>
  );
}
```

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│           AiComposerWrapper             │
│  (native: manages keyboard + scroll)    │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         ScrollView                │  │
│  │  (content insets managed natively)│  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │   Chat Messages             │  │  │
│  │  └─────────────────────────────┘  │  │
│  │                                   │  │
│  │  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐  │  │
│  │  │  Runway (pin-to-top inset)  │  │  │
│  │  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │      AiComposer                   │  │
│  │  (native: translated by keyboard) │  │
│  └───────────────────────────────────┘  │
│                                         │
│  [FAB] Scroll-to-bottom button          │
└─────────────────────────────────────────┘
```

### Pin-to-Top State Machine (iOS)

```
idle → armed → animating → pinned(enforce) → idle
                    ↓
               deferred (keyboard still closing)
                    ↓
               pinned(enforce)
```

1. **`idle`** — no pin active
2. **`armed`** — send triggered, waiting for content to grow
3. **`deferred`** — content grew but keyboard is still animating closed
4. **`animating`** — scroll animation to pinned offset in progress
5. **`pinned(enforce)`** — locked at offset, runway consumed as content streams

### Keyboard Animation Sync

| Platform | Mechanism | Sync Target |
|----------|-----------|-------------|
| iOS | `keyboardWillShow/Hide` notifications | `UIView.animate` with system curve |
| Android | `WindowInsetsAnimationCompat.Callback` | Frame-by-frame inset interpolation |

Both platforms translate the composer container and update scroll view padding in the same animation frame as the keyboard, producing a seamless native feel.

## Platform Notes

### iOS
- Uses `UITextView` for multiline input
- Keyboard curve extracted from notification `userInfo`
- Pin animation uses `UIViewPropertyAnimator` with velocity-based duration (1800 pts/sec)
- Expanded editor presents as `.pageSheet` with detent and grab handle
- `keyboardDismissMode: .interactive` — drag to dismiss
- Minimum deployment target: **iOS 15.1**

### Android
- Uses `EditText` with `TextWatcher`
- Keyboard tracked via `WindowInsetsAnimationCompat` (API 21+, compat)
- Send/stop buttons drawn with `Canvas` (no image assets needed)
- Composer translation applied frame-by-frame during IME animation
- Minimum SDK: **24**

## Types

```typescript
import type {
  AiComposerProps,
  AiComposerRef,
  AiComposerViewProps,
  AiComposerConstants,
  AiComposerWrapperProps,
  TextEventPayload,
  HeightEventPayload,
} from "expo-ai-composer";
```

## Requirements

- Expo SDK 55+
- React Native 0.83+
- iOS 15.1+
- Android SDK 24+

## License

MIT
