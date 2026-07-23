import CoreGraphics
import Testing
@testable import CrosshairCore

@Suite("ScreenTopology")
struct ScreenTopologyTests {
    private let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let side = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    private let above = CGRect(x: 0, y: 1080, width: 1920, height: 1080)

    @Test("identical frame lists match")
    func identicalMatch() {
        #expect(ScreenTopology.matches([main, side], [main, side]))
    }

    @Test("a pure reorder is not a divergence")
    func reorderMatches() {
        #expect(ScreenTopology.matches([main, side, above], [side, above, main]))
    }

    @Test("a changed frame is a divergence")
    func changedFrameDiverges() {
        let moved = side.offsetBy(dx: 0, dy: 100)
        #expect(!ScreenTopology.matches([main, side], [main, moved]))
    }

    @Test("a missing or extra display is a divergence")
    func countMismatchDiverges() {
        #expect(!ScreenTopology.matches([main, side], [main]))
        #expect(!ScreenTopology.matches([main], [main, side]))
    }

    @Test("duplicate frames compare as a multiset, not a set")
    func duplicatesCompareAsMultiset() {
        #expect(!ScreenTopology.matches([main, main, side], [main, side, side]))
        #expect(ScreenTopology.matches([main, main], [main, main]))
    }

    @Test("empty lists match")
    func emptyMatch() {
        #expect(ScreenTopology.matches([], []))
    }
}
