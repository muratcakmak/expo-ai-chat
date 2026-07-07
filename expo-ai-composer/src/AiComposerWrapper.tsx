import { requireNativeView } from "expo";
import type { ReactNode } from "react";
import type { ViewStyle, StyleProp } from "react-native";

export interface AiComposerWrapperProps {
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  /**
   * Enables ChatGPT-style pin-to-top behavior (runway below the pinned user message).
   *
   * NOTE: If omitted, native defaults apply (to preserve existing behavior).
   */
  pinToTopEnabled?: boolean;
  /**
   * Extra bottom inset (composer height + gap).
   * Keyboard height is automatically handled by native code.
   */
  extraBottomInset?: number;
  /**
   * Extra top inset for overlay/transparent headers (Android needs this; iOS can use contentInset).
   * Provide your header height in dp/points.
   */
  extraTopInset?: number;
  /**
   * Trigger scroll to bottom when this value changes.
   * Use Date.now() or a counter to trigger.
   */
  scrollToTopTrigger?: number;
}

type NativeAiComposerWrapperProps = {
  style?: StyleProp<ViewStyle>;
  pinToTopEnabled?: boolean;
  extraBottomInset?: number;
  extraTopInset?: number;
  scrollToTopTrigger?: number;
  children?: ReactNode;
};

const NativeView: React.ComponentType<NativeAiComposerWrapperProps> =
  requireNativeView("ExpoAiComposer", "AiComposerWrapper");

export function AiComposerWrapper({
  children,
  style,
  pinToTopEnabled,
  extraBottomInset = 0,
  extraTopInset = 0,
  scrollToTopTrigger = 0,
}: AiComposerWrapperProps) {
  return (
    <NativeView
      style={style}
      {...(pinToTopEnabled === undefined ? {} : { pinToTopEnabled })}
      extraBottomInset={extraBottomInset}
      extraTopInset={extraTopInset}
      scrollToTopTrigger={scrollToTopTrigger}
    >
      {children}
    </NativeView>
  );
}

export default AiComposerWrapper;
