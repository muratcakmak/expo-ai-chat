import ExpoModulesCore
import UIKit

/// CADisplayLink retains its target; this keeps it from retaining the view.
private final class DisplayLinkProxy: NSObject {
    private weak var target: AiComposerWrapper?
    init(target: AiComposerWrapper) { self.target = target }
    @objc func tick() { target?.syncComposerToLiveKeyboard() }
}

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
    // Zero-size view pinned to keyboardLayoutGuide.topAnchor. Discrete keyboard
    // notifications don't fire per-frame during interactive drag-to-dismiss, but UIKit
    // does keep the guide up to date — so this gives us a live keyboard top edge.
    private let keyboardAnchor = UIView()
    private var dragDisplayLink: CADisplayLink?
    // True from the moment a drag starts until the keyboard notification's animation
    // finishes. `currentKeyboardHeight` is stale for the frames between release and that
    // notification, so layout passes must not derive the composer position from it.
    private var isKeyboardTransitioning = false
    private var safeAreaBottom: CGFloat = 0
    private var lastComposerHeight: CGFloat = 0
    private var isFirstSend: Bool = true

    private let COMPOSER_KEYBOARD_GAP: CGFloat = 10
    private let MIN_BOTTOM_PADDING: CGFloat = 16
    // Gesture velocity (pt/ms, negative = finger moving down) at or below which releasing
    // a part-dragged keyboard dismisses it instead of springing it back.
    private let DISMISS_VELOCITY: CGFloat = -0.5

    // KVO observations
    private var extraBottomInsetObservation: NSKeyValueObservation?
    private var scrollToTopTriggerObservation: NSKeyValueObservation?
    private var pinToTopEnabledObservation: NSKeyValueObservation?

    @objc dynamic var pinToTopEnabled: Bool = false
    // Source of truth for the default is the TS layer (AiComposerWrapper.tsx), which
    // always passes this prop; keep the native default at 0 to match it.
    @objc dynamic var extraBottomInset: CGFloat = 0
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
        keyboardHandler.onDragStateChanged = { [weak self] isDragging in
            guard let self else { return }
            if isDragging { self.isKeyboardTransitioning = true }
            self.setLiveKeyboardTracking(isDragging)
        }
        keyboardHandler.onDragWillEnd = { [weak self] velocityY in
            self?.commitOrRestoreKeyboard(velocityY: velocityY)
        }
        setupKeyboardAnchor()
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
        dragDisplayLink?.invalidate()
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

    // MARK: - Live Keyboard Tracking

    private func setupKeyboardAnchor() {
        keyboardAnchor.isUserInteractionEnabled = false
        keyboardAnchor.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keyboardAnchor)
        keyboardLayoutGuide.followsUndockedKeyboard = true
        NSLayoutConstraint.activate([
            keyboardAnchor.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboardAnchor.widthAnchor.constraint(equalToConstant: 0),
            keyboardAnchor.heightAnchor.constraint(equalToConstant: 0),
            keyboardAnchor.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
        ])
    }

    /// Points of this view currently covered by the keyboard, read from the layout guide
    /// rather than the last notification — the only value that is correct mid-drag.
    private var liveKeyboardOverlap: CGFloat {
        layoutIfNeeded()
        return max(0, bounds.maxY - keyboardAnchor.frame.maxY)
    }

    /// Release of a part-dragged keyboard commits on downward inertia and springs back
    /// otherwise, rather than letting UIKit decide from drag distance alone.
    /// DISMISS_VELOCITY is the tuning knob: less negative dismisses more eagerly.
    private func commitOrRestoreKeyboard(velocityY: CGFloat) {
        let overlap = liveKeyboardOverlap
        // Untouched keyboard — an ordinary scroll with the keyboard up. Don't interfere.
        guard overlap > 0, overlap < currentKeyboardHeight - 1 else { return }

        if velocityY <= DISMISS_VELOCITY {
            window?.endEditing(true)
        } else {
            composerView?.focus()
        }
    }

    private func setLiveKeyboardTracking(_ enabled: Bool) {
        if enabled {
            guard dragDisplayLink == nil else { return }
            let link = CADisplayLink(
                target: DisplayLinkProxy(target: self),
                selector: #selector(DisplayLinkProxy.tick)
            )
            link.add(to: .main, forMode: .common)
            dragDisplayLink = link
        } else {
            dragDisplayLink?.invalidate()
            dragDisplayLink = nil
        }
    }

    // Deliberately does NOT notify JS — this runs at display rate.
    fileprivate func syncComposerToLiveKeyboard() {
        // No animation wrapper: the drag is already continuous, one update per frame.
        let height = liveKeyboardOverlap
        updateComposerTransform(keyboardHeight: height)
        updateScrollButtonTransform(keyboardHeight: height)
        keyboardHandler.applyLiveKeyboardHeight(height)
    }

    private func animateComposerAndButton(duration: Double, curve: UInt) {
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(
            withDuration: duration, delay: 0, options: options,
            animations: {
                self.updateComposerTransform(keyboardHeight: self.currentKeyboardHeight)
                self.updateScrollButtonTransform(keyboardHeight: self.currentKeyboardHeight)
            },
            completion: { _ in
                self.isKeyboardTransitioning = false
            }
        )
    }

    /// Where the composer sits when the keyboard is fully down.
    private var restingBottomOffset: CGFloat {
        max(safeAreaBottom, MIN_BOTTOM_PADDING)
    }

    private func updateComposerTransform(keyboardHeight: CGFloat) {
        guard let container = composerContainer else { return }
        // Clamped, not branched: for the last few points of an interactive drag the
        // keyboard top is above the resting offset, and following it there would dip the
        // composer below its resting position and snap back on release.
        let translation = -max(keyboardHeight + COMPOSER_KEYBOARD_GAP, restingBottomOffset)
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
        let buttonGap: CGFloat = 8
        return restingBottomOffset + composerHeight + buttonGap
    }

    private func updateScrollButtonTransform(keyboardHeight: CGFloat) {
        scrollButtonController.setTransform(buttonKeyboardTransform(keyboardHeight: keyboardHeight))
    }

    // The button's base offset already includes restingBottomOffset, so it only needs to
    // travel the distance the composer moves *beyond* resting — same clamp, same curve,
    // which is what keeps the 8pt gap constant instead of the two crossing mid-drag.
    private func buttonKeyboardTransform(keyboardHeight: CGFloat) -> CGAffineTransform {
        let travel = max(keyboardHeight + COMPOSER_KEYBOARD_GAP - restingBottomOffset, 0)
        guard travel > 0 else { return .identity }
        return CGAffineTransform(translationX: 0, y: -travel)
    }

    private func currentButtonKeyboardTransform() -> CGAffineTransform {
        buttonKeyboardTransform(keyboardHeight: currentKeyboardHeight)
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

        // Three sources, in priority order. Mid-drag the guide is the only accurate one.
        // Between release and the keyboard notification nothing is accurate, so leave the
        // transform alone and let the notification's animation carry it from where the
        // drag ended — deriving it from the stale currentKeyboardHeight is what used to
        // snap the composer back up before it fell.
        let isDragging = keyboardHandler.scrollView?.isDragging ?? false
        let keyboardHeight: CGFloat? = isDragging
            ? max(0, bounds.maxY - keyboardAnchor.frame.maxY)
            : (isKeyboardTransitioning ? nil : currentKeyboardHeight)

        if let keyboardHeight {
            if composerContainer != nil {
                updateComposerTransform(keyboardHeight: keyboardHeight)
            }
            updateScrollButtonTransform(keyboardHeight: keyboardHeight)
        }

        updateScrollButtonBasePosition()
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
