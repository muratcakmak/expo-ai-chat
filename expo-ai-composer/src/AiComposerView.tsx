import { requireNativeView } from "expo";
import {
  forwardRef,
  useCallback,
  useImperativeHandle,
  useState,
} from "react";
import { View, StyleSheet } from "react-native";

import type {
  AiComposerProps,
  AiComposerRef,
  AiComposerViewProps,
  TextEventPayload,
  HeightEventPayload,
} from "./ExpoAiComposer.types";

const NativeView: React.ComponentType<AiComposerViewProps> =
  requireNativeView("ExpoAiComposer");

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

    // Prop-based triggers for ref methods
    const [focusTrigger, setFocusTrigger] = useState(0);
    const [blurTrigger, setBlurTrigger] = useState(0);
    const [clearTrigger, setClearTrigger] = useState(0);

    useImperativeHandle(ref, () => ({
      focus: () => setFocusTrigger((v) => v + 1),
      blur: () => setBlurTrigger((v) => v + 1),
      clear: () => setClearTrigger((v) => v + 1),
    }), []);

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
      headerAccessory || leadingAccessory || trailingAccessory || footerAccessory;

    // Hide built-in send button when a trailing accessory replaces it
    const effectiveShowSendButton = trailingAccessory ? false : showSendButton;

    const nativeView = (
      <NativeView
        style={hasAccessories ? styles.nativeInput : [styles.standalone, style]}
        onChangeText={handleChangeText}
        onSend={handleSend}
        onStop={handleStop}
        onHeightChange={handleHeightChange}
        onKeyboardHeightChange={handleKeyboardHeightChange}
        onComposerFocus={handleComposerFocus}
        onComposerBlur={handleComposerBlur}
        showSendButton={effectiveShowSendButton}
        focusTrigger={focusTrigger}
        blurTrigger={blurTrigger}
        clearTrigger={clearTrigger}
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
