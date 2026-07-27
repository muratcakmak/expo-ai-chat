import type { ReactNode } from "react";
import type { StyleProp, ViewStyle } from "react-native";

// Event payloads from native
export type TextEventPayload = {
  text: string;
};

export type HeightEventPayload = {
  height: number;
};

/**
 * Fields shared by the low-level native view props (`AiComposerViewProps`) and the
 * high-level wrapper props (`AiComposerProps`). The two differ only in their event
 * callbacks (native event-wrapper vs unwrapped) and the wrapper's accessory slots.
 *
 * Declared as a type alias (not an interface): implicit index signatures are only
 * inferred when every intersection constituent is a type literal, so an interface
 * here would break consumers using `satisfies Record<string, unknown>`.
 */
export type AiComposerBaseProps = {
  /** Placeholder text shown when empty */
  placeholder?: string;

  /** Controlled text value */
  text?: string;

  /** Minimum height of the composer */
  minHeight?: number;

  /** Maximum height before scrolling */
  maxHeight?: number;

  /** Whether the send button is enabled */
  sendButtonEnabled?: boolean;

  /** Whether to render the trailing send/stop button (auto-hidden when trailingAccessory is provided) */
  showSendButton?: boolean;

  /** Whether the text input is editable */
  editable?: boolean;

  /** Whether to auto focus the input on mount */
  autoFocus?: boolean;

  /** Whether the AI is currently streaming (shows stop button) */
  isStreaming?: boolean;

  /** Enables a native full-height editor sheet once maxHeight is reached (iOS only) */
  expandedEditorEnabled?: boolean;

  /** Called when stop button is pressed */
  onStop?: () => void;

  /** Called when text input gains focus */
  onComposerFocus?: () => void;

  /** Called when text input loses focus */
  onComposerBlur?: () => void;

  /** Style for the container */
  style?: StyleProp<ViewStyle>;
};

// Props for the native view (raw native event wrappers).
// NOTE: kept as type-alias intersections (not interfaces) so the public props
// types retain implicit index signatures — consumers rely on e.g.
// `satisfies Record<string, unknown>`, which interfaces would break.
export type AiComposerViewProps = AiComposerBaseProps & {
  /** Called when text changes */
  onChangeText?: (event: { nativeEvent: TextEventPayload }) => void;

  /** Called when send button is pressed */
  onSend?: (event: { nativeEvent: TextEventPayload }) => void;

  /** Called when composer height changes (for auto-grow) */
  onHeightChange?: (event: { nativeEvent: HeightEventPayload }) => void;

  /** Called when keyboard height changes (for list footer) */
  onKeyboardHeightChange?: (event: { nativeEvent: HeightEventPayload }) => void;
};

// Simplified props for the wrapper component (unwrapped callbacks + slots)
export type AiComposerProps = AiComposerBaseProps & {
  /** Called when text changes */
  onChangeText?: (text: string) => void;

  /** Called when send button is pressed with the text */
  onSend?: (text: string) => void;

  /** Called when composer height changes */
  onHeightChange?: (height: number) => void;

  /** Called when keyboard height changes */
  onKeyboardHeightChange?: (height: number) => void;

  /** Content rendered above the input row (e.g., formatting toolbar) */
  headerAccessory?: ReactNode;

  /** Content rendered before the text input (e.g., attachment button) */
  leadingAccessory?: ReactNode;

  /** Content rendered after the text input, replacing the default send button */
  trailingAccessory?: ReactNode;

  /** Content rendered below the input row (e.g., model selector, file chips) */
  footerAccessory?: ReactNode;
};

// Ref methods exposed by the composer
export type AiComposerRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
};

// Module constants
export type AiComposerConstants = {
  defaultMinHeight: number;
  defaultMaxHeight: number;
  contentGap: number;
};
