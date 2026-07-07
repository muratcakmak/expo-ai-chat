import ExpoModulesCore

public class ExpoAiComposerModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoAiComposer")

    Constants([
      "defaultMinHeight": 48.0,
      "defaultMaxHeight": 120.0,
      "contentGap": 0.0
    ])

    // Composer View definition
    View(AiComposerView.self) {
      Prop("placeholder") { (view: AiComposerView, value: String) in
        view.placeholder = value
      }

      Prop("text") { (view: AiComposerView, value: String) in
        view.text = value
      }

      Prop("minHeight") { (view: AiComposerView, value: CGFloat) in
        view.minHeight = value
      }

      Prop("maxHeight") { (view: AiComposerView, value: CGFloat) in
        view.maxHeight = value
      }

      Prop("sendButtonEnabled") { (view: AiComposerView, value: Bool) in
        view.sendButtonEnabled = value
      }

      Prop("showSendButton") { (view: AiComposerView, value: Bool) in
        view.showSendButton = value
      }

      Prop("editable") { (view: AiComposerView, value: Bool) in
        view.editable = value
      }

      Prop("autoFocus") { (view: AiComposerView, value: Bool) in
        view.autoFocus = value
      }

      Prop("isStreaming") { (view: AiComposerView, value: Bool) in
        view.isStreaming = value
      }

      Prop("expandedEditorEnabled") { (view: AiComposerView, value: Bool) in
        view.expandedEditorEnabled = value
      }

      // Imperative view functions (dispatched on the main queue by the view DSL).
      AsyncFunction("focus") { (view: AiComposerView) in
        view.focus()
      }

      AsyncFunction("blur") { (view: AiComposerView) in
        view.blur()
      }

      AsyncFunction("clear") { (view: AiComposerView) in
        view.clear()
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

    // Keyboard-aware wrapper view
    View(AiComposerWrapper.self) {
      Prop("pinToTopEnabled") { (view: AiComposerWrapper, value: Bool) in
        view.pinToTopEnabled = value
      }

      Prop("extraBottomInset") { (view: AiComposerWrapper, value: CGFloat) in
        view.extraBottomInset = value
      }

      // No-op on iOS (kept for cross-platform API parity)
      Prop("extraTopInset") { (_: AiComposerWrapper, _: CGFloat) in }

      Prop("scrollToTopTrigger") { (view: AiComposerWrapper, value: Double) in
        view.scrollToTopTrigger = value
      }
    }
  }
}
