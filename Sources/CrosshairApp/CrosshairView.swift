import AppKit
import CrosshairCore

/// The `NSView` that draws one Overlay Window's slice of the Crosshair: a
/// horizontal and/or vertical line at the local positions handed to it by the
/// Geometry layer, styled from `Settings`.
///
/// The view is unflipped (origin bottom-left, +y up) so its coordinate space
/// matches the Cocoa-global convention `GeometryLayer` emits local positions in.
@MainActor
final class CrosshairView: NSView {
    private var settings: Settings
    private var lines: CrosshairLines?

    init(settings: Settings) {
        self.settings = settings
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CrosshairView is created in code, never from a nib")
    }

    override var isFlipped: Bool { false }

    func update(lines: CrosshairLines) {
        self.lines = lines
        needsDisplay = true
    }

    func apply(settings: Settings) {
        self.settings = settings
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let lines else { return }
        crosshairColor().setFill()
        let thickness = CGFloat(settings.thicknessPoints)

        if lines.verticalLineVisible {
            crispRect(
                NSRect(x: lines.verticalLineX - thickness / 2, y: 0, width: thickness, height: bounds.height)
            ).fill()
        }
        if lines.horizontalLineVisible {
            crispRect(
                NSRect(x: 0, y: lines.horizontalLineY - thickness / 2, width: bounds.width, height: thickness)
            ).fill()
        }
    }

    /// Snaps a line rect to whole device pixels so a thin line renders crisply
    /// regardless of the display's backing scale.
    private func crispRect(_ rect: NSRect) -> NSRect {
        backingAlignedRect(rect, options: .alignAllEdgesNearest)
    }

    private func crosshairColor() -> NSColor {
        let color = settings.crosshairColor
        let effectiveAlpha = color.alpha * (Double(settings.opacityPercent) / 100)
        return NSColor(
            srgbRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: effectiveAlpha
        )
    }
}
