import type { ReactNode } from "react";
import type { StyleProp, ViewStyle } from "react-native";

// Event payloads from native
export type TextEventPayload = {
  text: string;
};

export type HeightEventPayload = {
  height: number;
};

// Props for the native view (raw native event wrappers)
export type AiComposerViewProps = {
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

  /** Whether to render the trailing send/stop button */
  showSendButton?: boolean;

  /** Whether the text input is editable */
  editable?: boolean;

  /** Whether to auto focus the input on mount */
  autoFocus?: boolean;

  /** Trigger to focus the input — change value to trigger focus */
  focusTrigger?: number;

  /** Trigger to blur the input — change value to trigger blur */
  blurTrigger?: number;

  /** Trigger to clear the input — change value to trigger clear */
  clearTrigger?: number;

  /** Whether the AI is currently streaming (shows stop button) */
  isStreaming?: boolean;

  /** Enables a native full-height editor sheet once maxHeight is reached (iOS only) */
  expandedEditorEnabled?: boolean;

  /** Called when text changes */
  onChangeText?: (event: { nativeEvent: TextEventPayload }) => void;

  /** Called when send button is pressed */
  onSend?: (event: { nativeEvent: TextEventPayload }) => void;

  /** Called when stop button is pressed */
  onStop?: () => void;

  /** Called when composer height changes (for auto-grow) */
  onHeightChange?: (event: { nativeEvent: HeightEventPayload }) => void;

  /** Called when keyboard height changes (for list footer) */
  onKeyboardHeightChange?: (event: { nativeEvent: HeightEventPayload }) => void;

  /** Called when text input gains focus */
  onComposerFocus?: () => void;

  /** Called when text input loses focus */
  onComposerBlur?: () => void;

  /** Style for the container */
  style?: StyleProp<ViewStyle>;
};

// Simplified props for the wrapper component (unwrapped callbacks + slots)
export type AiComposerProps = {
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

  /** Called when text changes */
  onChangeText?: (text: string) => void;

  /** Called when send button is pressed with the text */
  onSend?: (text: string) => void;

  /** Called when stop button is pressed */
  onStop?: () => void;

  /** Called when composer height changes */
  onHeightChange?: (height: number) => void;

  /** Called when keyboard height changes */
  onKeyboardHeightChange?: (height: number) => void;

  /** Called when text input gains focus */
  onComposerFocus?: () => void;

  /** Called when text input loses focus */
  onComposerBlur?: () => void;

  /** Content rendered above the input row (e.g., formatting toolbar) */
  headerAccessory?: ReactNode;

  /** Content rendered before the text input (e.g., attachment button) */
  leadingAccessory?: ReactNode;

  /** Content rendered after the text input, replacing the default send button */
  trailingAccessory?: ReactNode;

  /** Content rendered below the input row (e.g., model selector, file chips) */
  footerAccessory?: ReactNode;

  /** Style for the outer container */
  style?: StyleProp<ViewStyle>;
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
