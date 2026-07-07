import CoreGraphics

/// The local line positions for one Overlay Window's slice of the Crosshair.
///
/// Coordinate convention: global cursor and display frames are in Cocoa global
/// space (origin bottom-left of the main display, +y up). Each display's local
/// space has its origin at the bottom-left of that display's frame, matching an
/// Overlay Window's content view. `horizontalLineY` / `verticalLineX` are in
/// that local space; the `*Visible` flags say whether the cursor's coordinate
/// falls within this display on the relevant axis (a line still spans displays
/// that share the cursor's y or x even when the cursor sits on a different one).
public struct CrosshairLines: Equatable, Sendable {
    public let horizontalLineY: CGFloat
    public let verticalLineX: CGFloat
    public let horizontalLineVisible: Bool
    public let verticalLineVisible: Bool

    public init(
        horizontalLineY: CGFloat,
        verticalLineX: CGFloat,
        horizontalLineVisible: Bool,
        verticalLineVisible: Bool
    ) {
        self.horizontalLineY = horizontalLineY
        self.verticalLineX = verticalLineX
        self.horizontalLineVisible = horizontalLineVisible
        self.verticalLineVisible = verticalLineVisible
    }
}

/// Pure mapping from a global cursor point + display frames to per-display line
/// specs. Never reads `NSScreen.screens`; everything it needs is passed in, so
/// the cursor-to-line mapping is verifiable in isolation.
public enum GeometryLayer {
    /// Returns one `CrosshairLines` per entry in `displayFrames`, index-aligned.
    ///
    /// A display shows the vertical line when the cursor's x is within its
    /// horizontal extent, and the horizontal line when the cursor's y is within
    /// its vertical extent (both bounds inclusive, so a cursor on a shared bezel
    /// edge lights up both neighbours).
    public static func lines(
        forCursor cursor: CGPoint,
        displayFrames: [CGRect]
    ) -> [CrosshairLines] {
        displayFrames.map { frame in
            CrosshairLines(
                horizontalLineY: cursor.y - frame.minY,
                verticalLineX: cursor.x - frame.minX,
                horizontalLineVisible: cursor.y >= frame.minY && cursor.y <= frame.maxY,
                verticalLineVisible: cursor.x >= frame.minX && cursor.x <= frame.maxX
            )
        }
    }
}
