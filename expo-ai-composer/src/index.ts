// Main component export
export { default as AiComposer } from "./AiComposerView";

// Native keyboard-aware wrapper for scroll views
export {
  AiComposerWrapper,
  type AiComposerWrapperProps,
} from "./AiComposerWrapper";

// Module with constants
export {
  default as ExpoAiComposerModule,
  constants,
} from "./ExpoAiComposerModule";

// Types
export type {
  AiComposerProps,
  AiComposerRef,
  AiComposerViewProps,
  AiComposerConstants,
  TextEventPayload,
  HeightEventPayload,
} from "./ExpoAiComposer.types";
