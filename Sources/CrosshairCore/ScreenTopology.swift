import CoreGraphics

/// Order-insensitive comparison of display-frame sets. `NSScreen.screens` only
/// guarantees the primary display first, so a same-topology reorder must not
/// read as a divergence — treating it as one caused spurious overlay rebuilds
/// (flicker plus a false "missed reconfiguration" log).
public enum ScreenTopology {
    /// Whether the two frame lists describe the same displays, compared as a
    /// multiset: order is ignored, duplicates are not collapsed (mirrored
    /// displays can share a frame).
    public static func matches(_ lhs: [CGRect], _ rhs: [CGRect]) -> Bool {
        sortedCanonically(lhs) == sortedCanonically(rhs)
    }

    private static func sortedCanonically(_ frames: [CGRect]) -> [CGRect] {
        frames.sorted { a, b in
            if a.minX != b.minX { return a.minX < b.minX }
            if a.minY != b.minY { return a.minY < b.minY }
            if a.width != b.width { return a.width < b.width }
            return a.height < b.height
        }
    }
}
