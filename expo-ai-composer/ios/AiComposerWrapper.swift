import ExpoModulesCore
import UIKit

class AiComposerWrapper: ExpoView, KeyboardAwareScrollHandlerDelegate {
    private let keyboardHandler = KeyboardAwareScrollHandler()
    private var hasAttached = false
    private lazy var scrollButtonController: ScrollToBottomButtonController = {
        ScrollToBottomButtonController(hostView: self) { [weak self] in
            self?.keyboardHandler.scrollToBottomAnimated()
        }
    }()
    private var currentKeyboardHeight: CGFloat = 0

    private weak var composerContainer: UIView?
    private weak var composerView: AiComposerView?
    private weak var registeredScrollView: UIScrollView?
    private var safeAreaBottom: CGFloat = 0
    private var lastComposerHeight: CGFloat = 0
    private var isFirstSend: Bool = true

    private let COMPOSER_KEYBOARD_GAP: CGFloat = 10
    private let MIN_BOTTOM_PADDING: CGFloat = 16

    // KVO observations
    private var extraBottomInsetObservation: NSKeyValueObservation?
    private var scrollToTopTriggerObservation: NSKeyValueObservation?
    private var pinToTopEnabledObservation: NSKeyValueObservation?

    @objc dynamic var pinToTopEnabled: Bool = false
    @objc dynamic var extraBottomInset: CGFloat = 48
    @objc dynamic var scrollToTopTrigger: Double = 0

    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        keyboardHandler.delegate = self
        keyboardHandler.onKeyboardMetricsChanged = { [weak self] height, duration, curve in
            guard let self else { return }
            self.currentKeyboardHeight = height
            self.animateComposerAndButton(duration: duration, curve: curve)
            self.composerView?.notifyKeyboardHeight(height)
        }
        setupScrollToBottomButton()
        setupPropertyObservers()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleComposerDidSend(_:)),
            name: .aiComposerDidSend,
            object: nil
        )
    }

    private func attachIfReady() {
        guard !hasAttached else { return }
        guard let sv = registeredScrollView else { return }
        let composerHeight = composerView?.bounds.height ?? extraBottomInset
        keyboardHandler.setBaseInset(composerHeight)
        keyboardHandler.attach(to: sv)
        hasAttached = true
    }

    private func findFirstScrollView(in view: UIView) -> UIScrollView? {
        if let sv = view as? UIScrollView { return sv }
        for sub in view.subviews {
            if let sv = findFirstScrollView(in: sub) { return sv }
        }
        return nil
    }

    private func findFirstComposerView(in view: UIView) -> AiComposerView? {
        if let composer = view as? AiComposerView { return composer }
        for sub in view.subviews {
            if let composer = findFirstComposerView(in: sub) { return composer }
        }
        return nil
    }

    private func directChildContainer(for view: UIView) -> UIView? {
        var container: UIView? = view
        while let parent = container?.superview, parent !== self {
            container = parent
        }
        return container
    }

    func registerComposerView(_ composer: AiComposerView) {
        composerView = composer
        composerContainer = directChildContainer(for: composer)
        attachIfReady()
        setNeedsLayout()
    }

    private func registerScrollViewIfNeeded(_ sv: UIScrollView) {
        if registeredScrollView === sv { return }
        registeredScrollView = sv
        attachIfReady()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        extraBottomInsetObservation?.invalidate()
        scrollToTopTriggerObservation?.invalidate()
        pinToTopEnabledObservation?.invalidate()
    }

    // MARK: - Property Observers (KVO)

    private func setupPropertyObservers() {
        let (extraObs, triggerObs, pinObs) = WrapperPropertyObservers.setup(
            wrapper: self,
            onExtraBottomInsetChange: { [weak self] oldValue, newValue in
                guard let self else { return }
                let delta = newValue - oldValue
                if delta > 0 {
                    self.keyboardHandler.adjustScrollForComposerGrowth(delta: delta)
                }
                self.keyboardHandler.setBaseInset(newValue)
                self.updateScrollButtonBasePosition()
            },
            onScrollToTopTrigger: { [weak self] in
                guard let self else { return }
                guard self.pinToTopEnabled else { return }
                self.keyboardHandler.requestPinForNextContentAppend()
            },
            onPinToTopEnabledChange: { [weak self] _, newValue in
                guard let self else { return }
                if newValue == false {
                    self.keyboardHandler.clearPinState(preserveScrollPosition: true)
                }
            }
        )
        extraBottomInsetObservation = extraObs
        scrollToTopTriggerObservation = triggerObs
        pinToTopEnabledObservation = pinObs
    }

    @objc private func handleComposerDidSend(_ notification: Notification) {
        guard let sender = notification.object as? AiComposerView else { return }
        if composerView == nil {
            registerComposerView(sender)
        }
        guard sender === composerView else { return }
        guard pinToTopEnabled else { return }

        // Skip native pin for the first send — JS handles the first-message
        // animation (slide from bottom to top). Native pin would fight it.
        if isFirstSend {
            isFirstSend = false
            return
        }

        keyboardHandler.requestPinForNextContentAppend()
    }

    private func animateComposerAndButton(duration: Double, curve: UInt) {
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.updateComposerTransform()
            self.updateScrollButtonTransform()
        }
    }

    private func updateComposerTransform() {
        guard let container = composerContainer else { return }
        let translation: CGFloat
        if currentKeyboardHeight > 0 {
            translation = -(currentKeyboardHeight + COMPOSER_KEYBOARD_GAP)
        } else {
            let bottomOffset = max(safeAreaBottom, MIN_BOTTOM_PADDING)
            translation = -bottomOffset
        }
        let currentTranslation = container.transform.ty
        if abs(currentTranslation - translation) > 0.5 {
            container.transform = CGAffineTransform(translationX: 0, y: translation)
        }
    }

    // MARK: - Scroll to Bottom Button

    private func setupScrollToBottomButton() {
        scrollButtonController.installIfNeeded()
        scrollButtonController.attachConstraints(
            centerXAnchor: centerXAnchor,
            bottomAnchor: bottomAnchor,
            baseOffset: calculateBaseButtonOffset()
        )
    }

    private func calculateBaseButtonOffset() -> CGFloat {
        let composerHeight = lastComposerHeight > 0 ? lastComposerHeight : extraBottomInset
        let bottomOffset = max(safeAreaBottom, MIN_BOTTOM_PADDING)
        let buttonGap: CGFloat = 8
        return bottomOffset + composerHeight + buttonGap
    }

    private func updateScrollButtonTransform() {
        let effectiveKeyboard = max(currentKeyboardHeight - safeAreaBottom, 0)
        if effectiveKeyboard > 0 {
            let translation = -(effectiveKeyboard + COMPOSER_KEYBOARD_GAP)
            scrollButtonController.setTransform(CGAffineTransform(translationX: 0, y: translation))
        } else {
            scrollButtonController.setTransform(.identity)
        }
    }

    private func currentButtonKeyboardTransform() -> CGAffineTransform {
        let effectiveKeyboard = max(currentKeyboardHeight - safeAreaBottom, 0)
        if effectiveKeyboard > 0 {
            let translation = -(effectiveKeyboard + COMPOSER_KEYBOARD_GAP)
            return CGAffineTransform(translationX: 0, y: translation)
        }
        return .identity
    }

    private func updateScrollButtonBasePosition() {
        scrollButtonController.setBaseOffset(calculateBaseButtonOffset())
    }

    private func showScrollButton() {
        let keyboardTransform = currentButtonKeyboardTransform()
        scrollButtonController.show(usingKeyboardTransform: keyboardTransform)
    }

    private func hideScrollButton() {
        let keyboardTransform = currentButtonKeyboardTransform()
        scrollButtonController.hide(usingKeyboardTransform: keyboardTransform)
    }

    // MARK: - KeyboardAwareScrollHandlerDelegate

    func scrollHandler(_ handler: KeyboardAwareScrollHandler, didUpdateScrollPosition isAtBottom: Bool) {
        DispatchQueue.main.async {
            if isAtBottom {
                self.hideScrollButton()
            } else {
                self.showScrollButton()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        safeAreaBottom = window?.safeAreaInsets.bottom ?? 34

        if composerContainer == nil, let composerView {
            composerContainer = directChildContainer(for: composerView)
        }

        if let composer = composerView {
            ComposerHeightCoordinator.updateIfNeeded(
                composerView: composer,
                lastComposerHeight: &lastComposerHeight,
                keyboardHandler: keyboardHandler
            )
        }

        if composerContainer != nil {
            updateComposerTransform()
        }

        updateScrollButtonBasePosition()
        updateScrollButtonTransform()
        scrollButtonController.bringToFront()
    }

    // MARK: - React Native Subview Management

    // didAddSubview is the architecture-agnostic UIView hook; it fires under both the
    // legacy and New Architecture, so no RN-specific insertReactSubview override is needed
    // (that Paper-era method was removed from ExpoView in the New Architecture / RN 0.86).
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if let sv = findFirstScrollView(in: subview) {
            registerScrollViewIfNeeded(sv)
        }
        if let composer = findFirstComposerView(in: subview) {
            registerComposerView(composer)
        }
        setNeedsLayout()
    }

    // MARK: - Touch Routing (runway)

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let button = scrollButtonController.buttonView() {
            let p = button.convert(point, from: self)
            if button.bounds.contains(p) {
                return button
            }
        }
        if let container = composerContainer {
            let p = container.convert(point, from: self)
            if container.bounds.contains(p) {
                return super.hitTest(point, with: event)
            }
        }
        if let sv = keyboardHandler.scrollView {
            let svFrame = sv.frame
            if point.y >= svFrame.minY && point.y <= svFrame.maxY {
                let contentHeight = sv.contentSize.height
                let offsetY = sv.contentOffset.y
                let contentBottomScreen = svFrame.minY + (contentHeight - offsetY)
                if point.y > contentBottomScreen {
                    return sv
                }
            }
        }
        return super.hitTest(point, with: event)
    }
}
