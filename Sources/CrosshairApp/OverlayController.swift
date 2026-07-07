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
    private var pendingRebuild: DispatchWorkItem?

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
    /// ADR-0002. The handler runs on the main queue, so the actor hop is safe.
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleRebuild()
            }
        }
    }

    private func scheduleRebuild() {
        pendingRebuild?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.rebuild()
            }
        }
        pendingRebuild = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    /// Tears down and recreates the full Overlay Window set from the current
    /// displays. Display reconfiguration is rare, so a full rebuild is simpler
    /// and less bug-prone than diffing (ADR-0002).
    private func rebuild() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows = NSScreen.screens.map { screen in
            OverlayWindow(displayFrame: screen.frame, settings: settings)
        }
        applyVisibility()
        cursorMoved(to: NSEvent.mouseLocation)
    }

    /// Flips the Crosshair between shown and hidden and returns the new state so
    /// the caller can mirror it (e.g. the menu's checkmark).
    func toggleVisibility() -> Bool {
        isVisible.toggle()
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
        pendingRebuild?.cancel()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        tracker?.stop()
    }
}
