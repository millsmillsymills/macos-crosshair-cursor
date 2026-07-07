import AppKit

/// Permission-free Tracking: a global `NSEvent` monitor on mouse-moved and the
/// drag masks that reads `NSEvent.mouseLocation` and publishes the global cursor
/// point. Mouse events through this API need no TCC permission (only key events
/// would), per ADR-0003.
///
/// The monitor's handler is delivered on the main run loop, so it hops onto the
/// main actor via `MainActor.assumeIsolated` before invoking `onMove`.
@MainActor
final class CursorTracker {
    private var globalMonitor: Any?
    private let onMove: @MainActor (CGPoint) -> Void

    init(onMove: @escaping @MainActor (CGPoint) -> Void) {
        self.onMove = onMove
    }

    func start() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [onMove] _ in
            MainActor.assumeIsolated {
                onMove(NSEvent.mouseLocation)
            }
        }
    }

    func stop() {
        guard let globalMonitor else { return }
        NSEvent.removeMonitor(globalMonitor)
        self.globalMonitor = nil
    }
}
