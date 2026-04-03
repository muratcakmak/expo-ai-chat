package expo.modules.expoaicomposer

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * Expo module for AiComposer.
 */
class ExpoAiComposerModule : Module() {

    override fun definition() = ModuleDefinition {
        Name("ExpoAiComposer")

        // AiComposerView
        View(AiComposerView::class) {
            Prop("placeholder") { view: AiComposerView, value: String ->
                view.placeholderText = value
            }

            Prop("text") { view: AiComposerView, value: String ->
                view.text = value
            }

            Prop("minHeight") { view: AiComposerView, value: Float ->
                view.minHeightDp = value
            }

            Prop("maxHeight") { view: AiComposerView, value: Float ->
                view.maxHeightDp = value
            }

            Prop("sendButtonEnabled") { view: AiComposerView, value: Boolean ->
                view.sendButtonEnabled = value
            }

            Prop("showSendButton") { view: AiComposerView, value: Boolean ->
                view.showSendButton = value
            }

            Prop("editable") { view: AiComposerView, value: Boolean ->
                view.editable = value
            }

            Prop("autoFocus") { view: AiComposerView, value: Boolean ->
                view.autoFocus = value
            }

            Prop("blurTrigger") { view: AiComposerView, value: Double ->
                if (value > 0) {
                    view.blur()
                }
            }

            Prop("focusTrigger") { view: AiComposerView, value: Double ->
                if (value > 0) {
                    view.focus()
                }
            }

            Prop("clearTrigger") { view: AiComposerView, value: Double ->
                if (value > 0) {
                    view.clear()
                }
            }

            Prop("isStreaming") { view: AiComposerView, value: Boolean ->
                view.isStreaming = value
            }

            Events(
                "onChangeText",
                "onSend",
                "onStop",
                "onHeightChange",
                "onKeyboardHeightChange",
                "onComposerFocus",
                "onComposerBlur"
            )
        }

        // AiComposerWrapper
        View(AiComposerWrapper::class) {
            Prop("pinToTopEnabled") { view: AiComposerWrapper, value: Boolean ->
                view.pinToTopEnabled = value
            }

            Prop("extraBottomInset") { view: AiComposerWrapper, value: Float ->
                view.extraBottomInset = value
            }

            Prop("scrollToTopTrigger") { view: AiComposerWrapper, value: Double ->
                view.scrollToTopTrigger = value
            }
        }
    }
}
