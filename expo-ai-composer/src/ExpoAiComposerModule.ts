import { NativeModule, requireNativeModule } from "expo";

import type { AiComposerConstants } from "./ExpoAiComposer.types";

declare class ExpoAiComposerModuleType extends NativeModule<{}> {
  defaultMinHeight: number;
  defaultMaxHeight: number;
  contentGap: number;
}

const ExpoAiComposerModule =
  requireNativeModule<ExpoAiComposerModuleType>("ExpoAiComposer");

export const constants: AiComposerConstants = {
  defaultMinHeight: ExpoAiComposerModule.defaultMinHeight,
  defaultMaxHeight: ExpoAiComposerModule.defaultMaxHeight,
  contentGap: ExpoAiComposerModule.contentGap,
};

export default ExpoAiComposerModule;
