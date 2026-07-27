import UIKit

protocol KeyboardAwareScrollHandlerDelegate: AnyObject {
    func scrollHandler(_ handler: KeyboardAwareScrollHandler, didUpdateScrollPosition isAtBottom: Bool)
}

class KeyboardAwareScrollHandler: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    weak var scrollView: UIScrollView?
    weak var delegate: KeyboardAwareScrollHandlerDelegate?
    var onKeyboardMetricsChanged: ((CGFloat, Double, UInt) -> Void)?
    // Brackets a drag gesture. During one, an interactively-dismissed keyboard follows the
    // finger with no per-frame notifications, so the composer needs its own display-rate
    // driver. Not scrollViewDidScroll: that goes quiet once the list hits its scroll
    // boundary while the keyboard is still moving.
    var onDragStateChanged: ((Bool) -> Void)?
    // Release of a drag, with the vertical gesture velocity. Negative means the finger was
    // moving down. Fired before onDragStateChanged(false).
    var onDragWillEnd: ((CGFloat) -> Void)?
    var baseBottomInset: CGFloat = 64
    private var keyboardHeight: CGFloat = 0
    private var wasAtBottom = false
    private var isAtBottom = true
    private var isKeyboardVisible = false
    private var isKeyboardHiding: Bool = false

    // Pin-to-top + runway state
    private enum PinState {
        case idle
        case armed(messageStartY: CGFloat)
        case deferred(messageStartY: CGFloat, contentHeightAfter: CGFloat)
        case animating(targetOffset: CGFloat)
        case pinned(targetOffset: CGFloat, enforce: Bool)
    }

    private var pinState: PinState = .idle
    private var runwayInset: CGFloat = 0
    private var pinnedOffset: CGFloat = 0
    private var userIsInteracting: Bool = false
    private var pendingPinnedCorrection: Bool = false
    private var lastPinnedCorrectionTime: CFTimeInterval = 0
    private let pinnedDriftThreshold: CGFloat = 3.0
    private let pinnedCorrectionMinInterval: CFTimeInterval = 1.0 / 30.0

    private var isPinActive: Bool {
        switch pinState {
        case .animating, .pinned: return true
        case .idle, .armed, .deferred: return false
        }
    }

    private var isPinAnimating: Bool {
        if case .animating = pinState { return true }
        return false
    }

    private var shouldPreserveScrollDuringInsetUpdates: Bool {
        switch pinState {
        case .idle: return false
        case .armed, .deferred, .animating, .pinned: return true
        }
    }

    private var isPinnedOrRunwayActive: Bool {
        isPinActive || runwayInset > 0
    }

    private func findScrollContentContainerView(in sv: UIScrollView) -> UIView? {
        if sv.contentSize.height > 0 {
            if let match = sv.subviews.first(where: { v in
                abs(v.frame.height - sv.contentSize.height) < 2 &&
                v.frame.width >= sv.bounds.width - 2
            }) {
                return match
            }
        }
        return sv.subviews.max(by: {
            ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height)
        })
    }

    func clearPinState(preserveScrollPosition: Bool = true) {
        pinState = .idle
        runwayInset = 0
        pinnedOffset = 0
        updateContentInset(preserveScrollPosition: preserveScrollPosition)
        recheckScrollPosition()
    }

    private func ensurePinnedOffset(reason: String) {
        guard let sv = scrollView else { return }
        guard isPinnedOrRunwayActive else { return }
        guard !userIsInteracting else { return }
        guard case .pinned(_, let enforce) = pinState, enforce else { return }
        if abs(sv.contentOffset.y - pinnedOffset) > pinnedDriftThreshold {
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: pinnedOffset), animated: false)
        }
    }

    private func schedulePinnedOffsetCorrection(reason: String) {
        guard case .pinned(_, let enforce) = pinState, enforce else { return }
        guard !pendingPinnedCorrection else { return }
        pendingPinnedCorrection = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingPinnedCorrection = false
            let now = CACurrentMediaTime()
            if (now - self.lastPinnedCorrectionTime) < self.pinnedCorrectionMinInterval {
                return
            }
            self.lastPinnedCorrectionTime = now
            self.ensurePinnedOffset(reason: reason)
        }
    }

    private func recomputeRunwayInset(baseInset: CGFloat) {
        guard isPinActive, let sv = scrollView else { return }
        let viewportH = sv.bounds.height
        guard viewportH > 0 else { return }
        let contentH = sv.contentSize.height
        let rawMaxOffset = contentH - viewportH + baseInset
        runwayInset = max(0, pinnedOffset - rawMaxOffset)
    }

    private var safeAreaBottom: CGFloat {
        scrollView?.window?.safeAreaInsets.bottom ?? 34
    }

    /// Where the composer rests when the keyboard is down. Mirrors
    /// AiComposerWrapper.restingBottomOffset — the two must agree or the composer and the
    /// content it sits above travel on different curves.
    private var restingBottomOffset: CGFloat {
        max(safeAreaBottom, 16)
    }

    /// Distance from the bottom of the viewport to the top of the composer, for a given
    /// keyboard height. Clamped, not branched: below the resting offset the composer stops
    /// following the keyboard, and the inset has to stop with it.
    private func composerClearance(forKeyboardHeight height: CGFloat) -> CGFloat {
        max(height + 10, restingBottomOffset)
    }

    override init() {
        super.init()
        setupKeyboardObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        contentSizeObservation?.invalidate()
        contentSizeObservation = nil
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
    }

    private func shouldAdjustScrollForKeyboard(_ scrollView: UIScrollView, keyboardHeight: CGFloat) -> Bool {
        let contentH = scrollView.contentSize.height
        let viewportH = scrollView.bounds.height
        guard viewportH > 0 else { return false }

        let currentRawMaxOffset = contentH - viewportH + scrollView.contentInset.bottom
        let currentMaxOffset = max(0, currentRawMaxOffset)

        let composerKeyboardGap: CGFloat = 10
        let projectedBottomInset = baseBottomInset + keyboardHeight + composerKeyboardGap
        let projectedRawMaxOffset = contentH - viewportH + projectedBottomInset
        let projectedMaxOffset = max(0, projectedRawMaxOffset)

        let shouldAdjustIgnoringPin: Bool = {
            if currentMaxOffset <= 0.5 {
                return projectedMaxOffset > 0.5
            }
            let threshold: CGFloat = 80
            return isNearBottom(scrollView, threshold: threshold)
        }()

        switch pinState {
        case .animating: return false
        case .pinned(_, let enforce) where enforce: return false
        default: break
        }

        return shouldAdjustIgnoringPin
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        let newKeyboardHeight = keyboardFrame.height
        onKeyboardMetricsChanged?(newKeyboardHeight, duration, curveValue)
        guard let scrollView = scrollView else { return }

        let isInitialShow = !isKeyboardVisible
        isKeyboardVisible = true

        if isInitialShow {
            wasAtBottom = shouldAdjustScrollForKeyboard(scrollView, keyboardHeight: newKeyboardHeight)
        }
        keyboardHeight = newKeyboardHeight

        let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)

        UIView.animate(
            withDuration: duration, delay: 0, options: animationOptions,
            animations: {
                let preserveDuringShow = !self.wasAtBottom || self.isPinActive
                self.updateContentInset(preserveScrollPosition: preserveDuringShow)
                if isInitialShow && self.wasAtBottom {
                    let contentHeight = scrollView.contentSize.height
                    let scrollViewHeight = scrollView.bounds.height
                    let bottomInset = scrollView.contentInset.bottom
                    let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
                    scrollView.contentOffset = CGPoint(x: 0, y: maxOffset)
                }
            },
            completion: { _ in
                if isInitialShow && self.wasAtBottom {
                    self.scrollToBottom(animated: false)
                }
            }
        )
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        onKeyboardMetricsChanged?(0, duration, curveValue)
        guard scrollView != nil else { return }

        keyboardHeight = 0
        isKeyboardVisible = false
        isKeyboardHiding = true

        let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)

        UIView.animate(
            withDuration: duration, delay: 0, options: animationOptions,
            animations: {
                self.updateContentInset(preserveScrollPosition: self.shouldPreserveScrollDuringInsetUpdates)
            },
            completion: { _ in
                self.isKeyboardHiding = false
                if case .deferred(let messageStartY, let contentHeightAfter) = self.pinState {
                    self.pinState = .idle
                    self.applyPinAfterSend(messageStartY: messageStartY, contentHeightAfter: contentHeightAfter)
                }
            }
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        // Prefer the scroll view's own screen (multi-window/scene correct); fall back to
        // the window bounds, then UIScreen.main as a last resort for older paths.
        let screenHeight = scrollView?.window?.windowScene?.screen.bounds.height
            ?? scrollView?.window?.bounds.height
            ?? UIScreen.main.bounds.height
        let isVisibleByFrame = keyboardFrame.origin.y < screenHeight
        let newKeyboardHeight = isVisibleByFrame ? keyboardFrame.height : 0

        if abs(newKeyboardHeight - keyboardHeight) <= 0.5 { return }
        onKeyboardMetricsChanged?(newKeyboardHeight, duration, curveValue)

        guard let scrollView = scrollView else {
            keyboardHeight = newKeyboardHeight
            isKeyboardVisible = newKeyboardHeight > 0.5
            return
        }

        let wasVisible = isKeyboardVisible
        keyboardHeight = newKeyboardHeight
        isKeyboardVisible = newKeyboardHeight > 0.5
        let shouldAdjust = shouldAdjustScrollForKeyboard(scrollView, keyboardHeight: newKeyboardHeight)
        if !wasVisible && isKeyboardVisible {
            wasAtBottom = shouldAdjust
        }

        let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
        UIView.animate(
            withDuration: duration, delay: 0, options: animationOptions,
            animations: {
                let preserveDuringFrame = !shouldAdjust || self.isPinActive
                self.updateContentInset(preserveScrollPosition: preserveDuringFrame)
                if shouldAdjust {
                    let contentHeight = scrollView.contentSize.height
                    let scrollViewHeight = scrollView.bounds.height
                    let bottomInset = scrollView.contentInset.bottom
                    let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
                    scrollView.contentOffset = CGPoint(x: 0, y: maxOffset)
                }
            },
            completion: { _ in
                if shouldAdjust {
                    if newKeyboardHeight > 0.5, self.wasAtBottom {
                        self.scrollToBottom(animated: false)
                    }
                }
            }
        )
    }

    private func isNearBottom(_ scrollView: UIScrollView, threshold: CGFloat = 100) -> Bool {
        if isPinnedOrRunwayActive {
            return scrollView.contentOffset.y >= (pinnedOffset - 60)
        }
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let bottomInset = scrollView.contentInset.bottom
        let currentOffset = scrollView.contentOffset.y
        let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
        return (maxOffset - currentOffset) < threshold
    }

    private func updateContentInset(preserveScrollPosition: Bool = false) {
        guard let scrollView = scrollView else { return }
        let savedOffset = preserveScrollPosition ? scrollView.contentOffset : nil

        let indicatorGapAboveInput: CGFloat = 1
        let composerHeight = max(0, baseBottomInset)
        let clearance = composerClearance(forKeyboardHeight: keyboardHeight)
        let baseInset = baseBottomInset + clearance
        let indicatorInset = clearance + composerHeight + indicatorGapAboveInput

        if isPinActive {
            recomputeRunwayInset(baseInset: baseInset)
        }

        let totalInset = baseInset + runwayInset
        scrollView.contentInset.bottom = totalInset
        scrollView.verticalScrollIndicatorInsets.bottom = indicatorInset

        if let savedOffset = savedOffset {
            if case .pinned(_, let enforce) = pinState, enforce, isPinnedOrRunwayActive {
                scrollView.setContentOffset(CGPoint(x: savedOffset.x, y: pinnedOffset), animated: false)
            } else if isPinAnimating && isPinnedOrRunwayActive {
                scrollView.setContentOffset(CGPoint(x: savedOffset.x, y: pinnedOffset), animated: false)
            } else {
                scrollView.setContentOffset(savedOffset, animated: false)
            }
        }
    }

    /// Per-frame inset tracking for an interactively-dragged keyboard. Shifts the inset and
    /// the offset by the same delta, which holds `maxOffset - offset` constant so the
    /// content keeps its distance from the composer instead of the composer sliding over
    /// it. Moving both together is also what keeps this from fighting the in-flight pan the
    /// way a bare offset write would.
    func applyLiveKeyboardHeight(_ height: CGFloat) {
        guard let scrollView else { return }
        // Pin-to-top owns the offset in these states; same guard as shouldAdjustScrollForKeyboard.
        switch pinState {
        case .animating, .pinned: return
        default: break
        }

        keyboardHeight = height
        let newInset = baseBottomInset + composerClearance(forKeyboardHeight: height)
        let delta = newInset - scrollView.contentInset.bottom
        guard abs(delta) > 0.5 else { return }

        scrollView.contentInset.bottom = newInset
        scrollView.verticalScrollIndicatorInsets.bottom =
            composerClearance(forKeyboardHeight: height) + max(0, baseBottomInset) + 1
        scrollView.contentOffset.y = max(
            -scrollView.contentInset.top,
            scrollView.contentOffset.y + delta
        )
    }

    private func scrollToBottom(animated: Bool) {
        guard let scrollView = scrollView else { return }
        if isPinnedOrRunwayActive {
            scrollView.setContentOffset(CGPoint(x: 0, y: pinnedOffset), animated: animated)
            return
        }
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let bottomInset = scrollView.contentInset.bottom
        let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
        scrollView.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: animated)
    }

    // MARK: - Public API

    private var tapGesture: UITapGestureRecognizer?
    private var contentSizeObservation: NSKeyValueObservation?

    func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        // Interactive drag-to-dismiss: the keyboard follows the finger. iOS posts no
        // per-frame keyboard notifications during this gesture, so the composer rides
        // along via onInteractiveDrag + keyboardLayoutGuide in AiComposerWrapper.
        scrollView.keyboardDismissMode = .interactive
        scrollView.delegate = self
        updateContentInset()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)
        tapGesture = tap

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { [weak self] _, change in
            guard let self,
                  let oldSize = change.oldValue,
                  let newSize = change.newValue,
                  oldSize.height != newSize.height
            else { return }

            if case .armed(let messageStartY) = self.pinState, newSize.height > oldSize.height {
                self.pinState = .idle
                self.applyPinAfterSend(messageStartY: messageStartY, contentHeightAfter: newSize.height)
            } else if self.isPinActive && self.runwayInset > 0 && newSize.height > oldSize.height {
                let growth = newSize.height - oldSize.height
                self.consumeRunway(by: growth)
            }

            DispatchQueue.main.async {
                self.checkAndUpdateScrollPosition()
            }
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkAndUpdateScrollPosition()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        userIsInteracting = true
        if case .pinned(let targetOffset, _) = pinState {
            pinState = .pinned(targetOffset: targetOffset, enforce: false)
        }
        onDragStateChanged?(true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { userIsInteracting = false }
        // Stops on release, not on deceleration end: the keyboard's fate is settled here
        // and the notification-driven animation takes over. Letting the display link run
        // past this point would fight that animation frame by frame.
        onDragStateChanged?(false)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        userIsInteracting = false
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard isKeyboardVisible || keyboardHeight > 0.5 else { return }
        // The wrapper owns this call: deciding whether a part-dragged keyboard commits or
        // springs back needs the live keyboard position, which only it can read.
        onDragWillEnd?(velocity.y)
    }

    private func checkAndUpdateScrollPosition() {
        guard let scrollView = scrollView else { return }
        let contentExceedsViewport = scrollView.contentSize.height > scrollView.bounds.height
        if !contentExceedsViewport {
            if !isAtBottom {
                isAtBottom = true
                delegate?.scrollHandler(self, didUpdateScrollPosition: true)
            }
            return
        }
        let newIsAtBottom = isNearBottom(scrollView)
        if newIsAtBottom != isAtBottom {
            isAtBottom = newIsAtBottom
            delegate?.scrollHandler(self, didUpdateScrollPosition: isAtBottom)
        }
    }

    func scrollToBottomAnimated() {
        scrollToBottom(animated: true)
    }

    func recheckScrollPosition() {
        checkAndUpdateScrollPosition()
    }

    func isUserNearBottom() -> Bool {
        guard let scrollView = scrollView else { return true }
        return isNearBottom(scrollView)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        scrollView?.window?.endEditing(true)
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func setBaseInset(_ inset: CGFloat, preserveScrollPosition: Bool = false) {
        baseBottomInset = inset
        updateContentInset(preserveScrollPosition: preserveScrollPosition)
    }

    // MARK: - Pin-to-top (public)

    func requestPinForNextContentAppend() {
        guard let sv = scrollView else { return }
        pinState = .idle
        runwayInset = 0
        pinnedOffset = 0
        let messageStartY = sv.contentSize.height
        guard messageStartY > 0.5 else { return }
        pinState = .armed(messageStartY: messageStartY)
        updateContentInset(preserveScrollPosition: true)
    }

    // MARK: - Pin-to-top (internal)

    private func applyPinAfterSend(messageStartY: CGFloat, contentHeightAfter: CGFloat) {
        guard let sv = scrollView else { return }
        guard !isPinAnimating else { return }

        let viewportH = sv.bounds.height
        guard viewportH > 0 else { return }

        // First message doesn't need pinning — content is already at top.
        // Pinning with messageStartY=0 creates a negative offset that scrolls above the screen.
        if messageStartY <= 0.5 {
            pinState = .idle
            runwayInset = 0
            pinnedOffset = 0
            return
        }

        let baseInset: CGFloat
        if keyboardHeight > 0 {
            baseInset = baseBottomInset + keyboardHeight
        } else {
            baseInset = baseBottomInset + safeAreaBottom
        }

        let topPadding: CGFloat = 16
        let topInset: CGFloat = sv.adjustedContentInset.top
        let minOffsetY: CGFloat = -topInset

        // Clamp to minimum valid scroll offset to prevent scrolling above the screen
        let desiredPinnedOffset = max(minOffsetY, messageStartY - topPadding - topInset)
        let rawMaxOffset = contentHeightAfter - viewportH + baseInset
        let neededRunway = max(0, desiredPinnedOffset - rawMaxOffset)

        pinnedOffset = desiredPinnedOffset
        runwayInset = neededRunway
        pinState = .pinned(targetOffset: desiredPinnedOffset, enforce: false)
        updateContentInset(preserveScrollPosition: true)

        let targetOffset = CGPoint(x: 0, y: desiredPinnedOffset)
        let deltaY = abs(sv.contentOffset.y - desiredPinnedOffset)
        let shouldAnimateOffset = deltaY > 0.5
        let isFirstMessagePin = messageStartY <= 0.5

        if !shouldAnimateOffset {
            sv.setContentOffset(targetOffset, animated: false)
            pinState = .pinned(targetOffset: desiredPinnedOffset, enforce: true)
            return
        }

        let velocity: CGFloat = 1800
        let minDuration: TimeInterval = 0.16
        let maxDuration: TimeInterval = 0.26
        let pinDuration = min(maxDuration, max(minDuration, TimeInterval(deltaY / velocity)))
        pinState = .animating(targetOffset: desiredPinnedOffset)

        let timing = UICubicTimingParameters(animationCurve: .easeOut)
        let shouldAnimateReveal = (!userIsInteracting && !isFirstMessagePin)
        let container = (shouldAnimateReveal ? findScrollContentContainerView(in: sv) : nil)
        let originalAlpha = container?.alpha ?? 1
        let originalTransform = container?.transform ?? .identity
        if let container {
            container.alpha = min(container.alpha, 0.96)
            container.transform = container.transform.concatenating(CGAffineTransform(translationX: 0, y: 6))
        }

        let animator = UIViewPropertyAnimator(duration: pinDuration, timingParameters: timing)
        animator.addAnimations {
            sv.contentOffset = targetOffset
            container?.alpha = originalAlpha
            container?.transform = originalTransform
        }
        animator.addCompletion { [weak self, weak sv] _ in
            guard let self, let sv else { return }
            sv.setContentOffset(targetOffset, animated: false)
            self.pinState = .pinned(targetOffset: desiredPinnedOffset, enforce: true)
            if let container {
                container.alpha = originalAlpha
                container.transform = originalTransform
            }
        }
        animator.startAnimation()
    }

    private func consumeRunway(by contentGrowth: CGFloat) {
        guard contentGrowth > 0 else { return }
        updateContentInset(preserveScrollPosition: true)
        if runwayInset <= 0.5, keyboardHeight <= 0.5, !isKeyboardVisible, !isKeyboardHiding {
            pinnedOffset = 0
            pinState = .idle
        }
        schedulePinnedOffsetCorrection(reason: "consumeRunway")
    }

    func adjustScrollForComposerGrowth(delta: CGFloat) {
        guard let scrollView = scrollView, delta > 0 else { return }
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let currentInset = scrollView.contentInset.bottom
        let currentOffset = scrollView.contentOffset.y
        let currentMaxOffset = max(0, contentHeight - scrollViewHeight + currentInset)
        let distanceFromBottom = currentMaxOffset - currentOffset
        let nearBottom = distanceFromBottom < 100
        guard nearBottom else { return }
        let newOffset = currentOffset + delta
        let bottomInset = currentInset + delta
        let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
        let clampedOffset = max(0, min(newOffset, maxOffset))
        scrollView.setContentOffset(CGPoint(x: 0, y: clampedOffset), animated: false)
    }
}
