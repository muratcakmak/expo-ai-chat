import { requireNativeView } from "expo";
import { forwardRef, useCallback, useImperativeHandle, useRef } from "react";
import { View, StyleSheet } from "react-native";

import type {
  AiComposerProps,
  AiComposerRef,
  AiComposerViewProps,
  TextEventPayload,
  HeightEventPayload,
} from "./ExpoAiComposer.types";

/**
 * Imperative methods the native view exposes on its ref. `requireNativeView`
 * assigns these to the component prototype so they are callable via the ref.
 * They are async view functions dispatched natively, so each returns a promise
 * that can reject with ViewNotFound if the view unmounts mid-call.
 */
interface NativeAiComposerViewRef {
  focus: () => Promise<void>;
  blur: () => Promise<void>;
  clear: () => Promise<void>;
}

const NativeView: React.ComponentType<
  AiComposerViewProps & {
    ref?: React.RefObject<NativeAiComposerViewRef | null>;
  }
> = requireNativeView("ExpoAiComposer");

const AiComposerView = forwardRef<AiComposerRef, AiComposerProps>(
  (props, ref) => {
    const {
      onChangeText,
      onSend,
      onStop,
      onHeightChange,
      onKeyboardHeightChange,
      onComposerFocus,
      onComposerBlur,
      headerAccessory,
      leadingAccessory,
      trailingAccessory,
      footerAccessory,
      showSendButton = true,
      style,
      ...rest
    } = props;

    const nativeRef = useRef<NativeAiComposerViewRef | null>(null);

    useImperativeHandle(
      ref,
      () => ({
        // These native view functions are async and can reject with ViewNotFound
        // during an unmount race; swallow that benign dev-only rejection so it does
        // not surface as an unhandled promise-rejection warning. Behavior is
        // otherwise identical (fire-and-forget focus/blur/clear).
        focus: () => nativeRef.current?.focus()?.catch?.(() => {}),
        blur: () => nativeRef.current?.blur()?.catch?.(() => {}),
        clear: () => nativeRef.current?.clear()?.catch?.(() => {}),
      }),
      []
    );

    // Event handlers that unwrap nativeEvent
    const handleChangeText = useCallback(
      (event: { nativeEvent: TextEventPayload }) => {
        onChangeText?.(event.nativeEvent.text);
      },
      [onChangeText]
    );

    const handleSend = useCallback(
      (event: { nativeEvent: TextEventPayload }) => {
        onSend?.(event.nativeEvent.text);
      },
      [onSend]
    );

    const handleStop = useCallback(() => {
      onStop?.();
    }, [onStop]);

    const handleHeightChange = useCallback(
      (event: { nativeEvent: HeightEventPayload }) => {
        onHeightChange?.(event.nativeEvent.height);
      },
      [onHeightChange]
    );

    const handleKeyboardHeightChange = useCallback(
      (event: { nativeEvent: HeightEventPayload }) => {
        onKeyboardHeightChange?.(event.nativeEvent.height);
      },
      [onKeyboardHeightChange]
    );

    const handleComposerFocus = useCallback(() => {
      onComposerFocus?.();
    }, [onComposerFocus]);

    const handleComposerBlur = useCallback(() => {
      onComposerBlur?.();
    }, [onComposerBlur]);

    const hasAccessories =
      headerAccessory ||
      leadingAccessory ||
      trailingAccessory ||
      footerAccessory;

    // Hide built-in send button when a trailing accessory replaces it
    const effectiveShowSendButton = trailingAccessory ? false : showSendButton;

    const nativeView = (
      <NativeView
        ref={nativeRef}
        style={hasAccessories ? styles.nativeInput : [styles.standalone, style]}
        onChangeText={handleChangeText}
        onSend={handleSend}
        onStop={handleStop}
        onHeightChange={handleHeightChange}
        onKeyboardHeightChange={handleKeyboardHeightChange}
        onComposerFocus={handleComposerFocus}
        onComposerBlur={handleComposerBlur}
        showSendButton={effectiveShowSendButton}
        {...rest}
      />
    );

    if (!hasAccessories) {
      return nativeView;
    }

    return (
      <View style={[styles.container, style]}>
        {headerAccessory}
        <View style={styles.inputRow}>
          {leadingAccessory}
          {nativeView}
          {trailingAccessory}
        </View>
        {footerAccessory}
      </View>
    );
  }
);

AiComposerView.displayName = "AiComposerView";

const styles = StyleSheet.create({
  standalone: {
    flex: 1,
    alignSelf: "stretch",
  },
  container: {
    alignSelf: "stretch",
  },
  inputRow: {
    flexDirection: "row",
    alignItems: "flex-end",
  },
  nativeInput: {
    flex: 1,
  },
});

export default AiComposerView;
