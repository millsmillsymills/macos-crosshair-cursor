import AppKit
import CrosshairCore

/// A single Overlay Window: borderless, transparent, click-through, sized to one
/// display's frame and floating just below the menu bar on every Space. It hosts
/// a `CrosshairView` and forwards the Geometry layer's per-display line specs to
/// it. There is exactly one per `NSScreen`.
@MainActor
final class OverlayWindow: NSWindow {
    /// This display's frame in Cocoa global space, captured when the window was
    /// built. The controller feeds these frames back into `GeometryLayer`.
    let displayFrame: CGRect

    private let crosshairView: CrosshairView

    init(displayFrame: CGRect, settings: Settings) {
        self.displayFrame = displayFrame
        self.crosshairView = CrosshairView(settings: settings)
        super.init(
            contentRect: displayFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true

        // Just below the menu bar: visible over normal and floating windows but
        // never occluding the menu bar itself.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 1)
        // `.canJoinAllSpaces` alone never joins full-screen Spaces;
        // `.fullScreenAuxiliary` is what keeps the Crosshair visible when
        // another app is full screen on this display.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        contentView = crosshairView
    }

    func update(lines: CrosshairLines) {
        crosshairView.update(lines: lines)
    }

    func apply(settings: Settings) {
        crosshairView.apply(settings: settings)
    }
}
