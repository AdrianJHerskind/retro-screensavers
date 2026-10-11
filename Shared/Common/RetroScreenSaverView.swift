import ScreenSaver

/// Base class for every saver in the collection. It handles what all of them need from the
/// host, so a subclass overrides `setAnimating(_:)` and, if it cares, `sizeDidSettle()`:
///
/// - Since macOS Sonoma, `stopAnimation()` isn't reliably called and the legacyScreenSaver host
///   keeps old instances alive (and drawing). The "will stop" notification is the dependable
///   signal, so this stops animating on it and quits the lingering host.
/// - Size changes are debounced, so a live window resize in the harness reports once at the end.
class RetroScreenSaverView: ScreenSaverView {
    private var willStopObserver: NSObjectProtocol?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        willStopObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.screenSaverWillStop()
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        if let willStopObserver {
            DistributedNotificationCenter.default().removeObserver(willStopObserver)
        }
    }

    /// Starts or stops drawing. Called from start/stopAnimation() and when the screen saver stops.
    func setAnimating(_ isAnimating: Bool) {}

    /// Called once the view's size has stopped changing.
    func sizeDidSettle() {}

    override func startAnimation() {
        super.startAnimation()
        setAnimating(true)
    }

    override func stopAnimation() {
        super.stopAnimation()
        setAnimating(false)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        guard bounds.size != oldSize else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(notifySizeDidSettle), object: nil)
        perform(#selector(notifySizeDidSettle), with: nil, afterDelay: 0.3)
    }

    @objc private func notifySizeDidSettle() {
        sizeDidSettle()
    }

    private func screenSaverWillStop() {
        setAnimating(false)
        // Quit the lingering host process so stale instances don't pile up across activations;
        // macOS launches a fresh one next time. Never do this for the System Settings preview
        // or when hosted by the test harness.
        if !isPreview, ProcessInfo.processInfo.processName.hasPrefix("legacyScreenSaver") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }
    }
}
