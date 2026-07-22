import AppKit

/// Permission-free Tracking: global + local `NSEvent` monitors on mouse-moved
/// and the drag masks that read `NSEvent.mouseLocation` and publish the global
/// cursor point. Mouse events through this API need no TCC permission (only key
/// events would), per ADR-0003. The local monitor matters because global
/// monitors skip events delivered to this app itself — without it the
/// Crosshair freezes whenever Crosshair is frontmost (Preferences open).
///
/// The monitors' handlers are delivered on the main run loop, so they hop onto
/// the main actor via `MainActor.assumeIsolated` before invoking `onMove`.
@MainActor
final class CursorTracker {
    private var globalMonitor: Any?
    private var localMonitor: Any?
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
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [onMove] event in
            MainActor.assumeIsolated {
                onMove(NSEvent.mouseLocation)
            }
            return event
        }
        let globalInstalled = globalMonitor != nil
        let localInstalled = localMonitor != nil
        if !globalInstalled || !localInstalled {
            Log.tracking.error(
                "mouse monitor install failed (global=\(globalInstalled), local=\(localInstalled))"
            )
        } else {
            Log.tracking.notice("global and local mouse monitors installed")
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
