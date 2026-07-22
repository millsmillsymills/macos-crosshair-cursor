import AppKit
import CrosshairCore

/// Owns the set of Overlay Windows (one per `NSScreen`) and drives them from
/// Tracking. This is the *only* type that reads `NSScreen.screens`; it captures
/// each display's frame and passes those frames into the pure `GeometryLayer`,
/// keeping the cursor-to-line mapping testable in isolation.
@MainActor
final class OverlayController {
    private var overlayWindows: [OverlayWindow] = []
    private var tracker: CursorTracker?
    private var settings: Settings
    private var isVisible = true
    private var screenObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var pendingRebuild: DispatchWorkItem?
    private var resyncTimer: Timer?

    var visible: Bool { isVisible }

    init(settings: Settings) {
        self.settings = settings
    }

    func start() {
        rebuild()
        let tracker = CursorTracker { [weak self] point in
            self?.cursorMoved(to: point)
        }
        tracker.start()
        self.tracker = tracker
        observeScreenChanges()
        startResyncTimer()
    }

    /// Live-applies new appearance Settings to every Crosshair and remembers them
    /// so windows created by a later Rebuild start with the current look.
    func apply(settings: Settings) {
        self.settings = settings
        for window in overlayWindows {
            window.apply(settings: settings)
        }
    }

    /// Watches for display configuration changes (dock/undock, rearrange) and
    /// debounces the burst of notifications into a single Rebuild (~100ms), per
    /// ADR-0002. Also logs screen wake, which reorders windows in the window
    /// server without necessarily changing screen parameters — the prime window
    /// for the overlay-disappears-on-one-screen glitch. Both handlers run on
    /// the main queue, so the actor hop is safe.
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.overlay.notice("screen parameters changed; scheduling rebuild")
                self?.scheduleRebuild()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.overlay.notice("screens woke; scheduling rebuild")
                self?.scheduleRebuild()
            }
        }
    }

    private func scheduleRebuild() {
        pendingRebuild?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.pendingRebuild = nil
                self?.rebuild()
            }
        }
        pendingRebuild = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    /// Safety net for missed display reconfigurations: the system occasionally
    /// starts a reconfigure and never posts the completion that would fire
    /// `didChangeScreenParameters`, leaving the window set built for a stale
    /// topology. Every 30s, compare the built frames against the live screens
    /// and rebuild on divergence. The timer closure runs on the main run loop,
    /// so the actor hop is safe.
    private func startResyncTimer() {
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resyncIfScreensDiverged()
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        resyncTimer = timer
    }

    private func resyncIfScreensDiverged() {
        guard pendingRebuild == nil else { return }
        let current = NSScreen.screens.map(\.frame)
        let built = overlayWindows.map(\.displayFrame)
        guard current != built else { return }
        Log.overlay.error(
            "overlay windows diverged from screens (missed reconfiguration); rebuilding"
        )
        rebuild()
    }

    /// Tears down and recreates the full Overlay Window set from the current
    /// displays. Display reconfiguration is rare, so a full rebuild is simpler
    /// and less bug-prone than diffing (ADR-0002).
    private func rebuild() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        let screens = NSScreen.screens
        overlayWindows = screens.map { screen in
            OverlayWindow(displayFrame: screen.frame, settings: settings)
        }
        applyVisibility()
        cursorMoved(to: NSEvent.mouseLocation)

        let described = zip(screens, overlayWindows).map { screen, window in
            "\(screen.localizedName) frame=\(NSStringFromRect(screen.frame)) "
                + "scale=\(screen.backingScaleFactor) window=\(window.windowNumber)"
        }
        let summary = described.joined(separator: "; ")
        let visible = isVisible
        Log.overlay.notice(
            "rebuilt \(described.count) windows visible=\(visible): \(summary, privacy: .public)"
        )
        if screens.isEmpty {
            Log.overlay.error("no screens reported by NSScreen.screens; overlay has no windows")
        }
    }

    /// Flips the Crosshair between shown and hidden and returns the new state so
    /// the caller can mirror it (e.g. the menu's checkmark).
    func toggleVisibility() -> Bool {
        isVisible.toggle()
        Log.overlay.notice("visibility toggled to \(self.isVisible)")
        applyVisibility()
        return isVisible
    }

    private func applyVisibility() {
        for window in overlayWindows {
            if isVisible {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
    }

    private func cursorMoved(to point: CGPoint) {
        let frames = overlayWindows.map(\.displayFrame)
        let lines = GeometryLayer.lines(forCursor: point, displayFrames: frames)
        for (window, line) in zip(overlayWindows, lines) {
            window.update(lines: line)
        }
    }

    isolated deinit {
        resyncTimer?.invalidate()
        pendingRebuild?.cancel()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        tracker?.stop()
    }
}
