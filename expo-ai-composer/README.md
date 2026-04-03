# expo-ai-composer

A native keyboard-aware AI composer component for React Native. Provides smooth, system-level keyboard animations and a ChatGPT-style pin-to-top scroll experience for chat UIs.

## Features

- **Native keyboard tracking** — pixel-perfect keyboard animations that match system apps like iMessage
- **Pin-to-top scroll** — new messages pin to the top of the viewport with a runway for streaming responses
- **Auto-growing text input** — multiline input that grows between configurable min/max heights
- **Send/Stop button** — built-in send and streaming stop buttons with haptic feedback
- **Scroll-to-bottom FAB** — appears when scrolled away from bottom, animates with keyboard
- **Customizable slots** — `headerAccessory`, `leadingAccessory`, `trailingAccessory`, `footerAccessory` for custom UI around the input
- **Transparent background** — style the composer background from React Native
- **Expanded editor** — full-screen text editor sheet when input reaches max height (iOS)
- **Imperative ref methods** — `focus()`, `blur()`, `clear()` via ref
- **iOS & Android** — full native implementations on both platforms

## Installation

```bash
npx expo install expo-ai-composer
```

## Quick Start

```tsx
import { useState } from "react";
import { View, ScrollView } from "react-native";
import { AiComposer, AiComposerWrapper, constants } from "expo-ai-composer";

export default function ChatScreen() {
  const [composerHeight, setComposerHeight] = useState(constants.defaultMinHeight);
  const [isStreaming, setIsStreaming] = useState(false);

  return (
    <View style={{ flex: 1 }}>
      <AiComposerWrapper
        style={{ flex: 1 }}
        pinToTopEnabled
        extraBottomInset={composerHeight}
      >
        <ScrollView style={{ flex: 1 }}>
          {/* Your messages here */}
        </ScrollView>

        <View style={{
          position: "absolute",
          bottom: 0, left: 0, right: 0,
          height: composerHeight,
        }}>
          <AiComposer
            style={{ flex: 1 }}
            placeholder="Ask anything"
            onSend={(text) => handleSend(text)}
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

## Components

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
| `expandedEditorEnabled` | `boolean` | `false` | Enable full-screen editor (iOS) |
| `onChangeText` | `(text: string) => void` | — | Text change callback |
| `onSend` | `(text: string) => void` | — | Send button pressed |
| `onStop` | `() => void` | — | Stop button pressed |
| `onHeightChange` | `(height: number) => void` | — | Composer height changed |
| `onKeyboardHeightChange` | `(height: number) => void` | — | Keyboard height changed |
| `onComposerFocus` | `() => void` | — | Input gained focus |
| `onComposerBlur` | `() => void` | — | Input lost focus |
| `style` | `ViewStyle` | — | Container style |

#### Accessory Slots

Wrap the native input with custom React Native views:

| Prop | Type | Description |
|------|------|-------------|
| `headerAccessory` | `ReactNode` | Above the input row (e.g., formatting toolbar) |
| `leadingAccessory` | `ReactNode` | Before the input (e.g., attachment button) |
| `trailingAccessory` | `ReactNode` | After the input, replaces built-in send button |
| `footerAccessory` | `ReactNode` | Below the input row (e.g., model selector) |

When `trailingAccessory` is provided, the built-in send button is automatically hidden.

#### Ref Methods

```tsx
const composerRef = useRef<AiComposerRef>(null);

composerRef.current?.focus();  // Focus the input
composerRef.current?.blur();   // Blur the input
composerRef.current?.clear();  // Clear the text
```

### `<AiComposerWrapper />`

Keyboard-aware container that manages scroll position and composer animation.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `pinToTopEnabled` | `boolean` | — | Enable ChatGPT-style pin-to-top |
| `extraBottomInset` | `number` | `0` | Composer height (keyboard height handled natively) |
| `extraTopInset` | `number` | `0` | Extra top inset for transparent headers (Android) |
| `scrollToTopTrigger` | `number` | `0` | Trigger pin when value changes (use `Date.now()`) |
| `children` | `ReactNode` | — | ScrollView + composer |
| `style` | `ViewStyle` | — | Container style |

#### Behavior

- **Keyboard opens at bottom** — auto-scrolls to keep content visible
- **Keyboard opens mid-scroll** — opens over content (no scroll)
- **Pin-to-top** — new messages pin to top, response streams below with runway
- **First message** — special treatment: native pin is skipped so you can implement your own JS animation (slide from bottom)
- **Scroll-to-bottom button** — appears when scrolled away, follows keyboard

### `constants`

```tsx
import { constants } from "expo-ai-composer";

constants.defaultMinHeight; // 48
constants.defaultMaxHeight; // 120
constants.contentGap;       // 0
```

## Layout Pattern

The recommended layout places the `ScrollView` and composer inside the wrapper:

```tsx
<AiComposerWrapper
  style={{ flex: 1 }}
  pinToTopEnabled
  extraBottomInset={composerHeight}
>
  <ScrollView style={{ flex: 1 }}>
    {messages.map(renderMessage)}
  </ScrollView>

  <View style={{
    position: "absolute",
    bottom: 0, left: 0, right: 0,
    height: composerHeight,
  }}>
    <View style={{ paddingHorizontal: 16, flex: 1 }}>
      <View style={{ borderRadius: 24, overflow: "hidden", backgroundColor: "#F2F2F7", flex: 1 }}>
        <AiComposer style={{ flex: 1 }} ... />
      </View>
    </View>
  </View>
</AiComposerWrapper>
```

Key points:
- No `paddingBottom` on scroll content — native handles spacing via `extraBottomInset`
- Composer container uses `height: composerHeight` from `onHeightChange`
- Native code handles safe area and keyboard positioning
- Use `pointerEvents="box-none"` on composer container if needed

## First Message Animation

The native pin-to-top automatically skips the first send. Implement the first message animation in your app using React Native's `Animated` API or Reanimated:

```tsx
import { Animated, useWindowDimensions } from "react-native";

function FirstMessageAnimated({ children, isFirst }) {
  const { height } = useWindowDimensions();
  const translateY = useRef(new Animated.Value(isFirst ? height * 0.6 : 0)).current;
  const opacity = useRef(new Animated.Value(isFirst ? 0 : 1)).current;

  useEffect(() => {
    if (!isFirst) return;
    Animated.parallel([
      Animated.spring(translateY, {
        toValue: 0,
        damping: 20,
        stiffness: 180,
        useNativeDriver: true,
      }),
      Animated.timing(opacity, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  return (
    <Animated.View style={{ transform: [{ translateY }], opacity }}>
      {children}
    </Animated.View>
  );
}
```

## Platform Notes

### iOS
- Keyboard animations use native `UIView.animate` with the system keyboard curve
- Pin-to-top uses `UIViewPropertyAnimator` with velocity-based duration
- Expanded editor presents as a `.pageSheet` with grab handle
- `keyboardDismissMode: .interactive` enabled on scroll view
- Minimum deployment target: iOS 15.1

### Android
- Keyboard animations use `WindowInsetsAnimationCompat.Callback`
- Pin-to-top uses `ScrollView.smoothScrollTo()`
- Send/stop buttons are drawn with Canvas (no image assets)
- IME animation syncs composer translation with keyboard frame
- Minimum SDK: 24

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

## License

MIT
