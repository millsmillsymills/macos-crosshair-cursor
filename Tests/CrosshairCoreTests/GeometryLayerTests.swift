import CoreGraphics
import Testing
@testable import CrosshairCore

@Suite("GeometryLayer")
struct GeometryLayerTests {
    private let mainDisplay = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("cursor off every display: lines invisible everywhere, positions still mapped")
    func offScreen() {
        let frames = [mainDisplay, CGRect(x: 1920, y: 0, width: 1920, height: 1080)]
        let result = GeometryLayer.lines(forCursor: CGPoint(x: -50, y: 2000), displayFrames: frames)

        #expect(result.count == 2)
        for lines in result {
            #expect(!lines.horizontalLineVisible)
            #expect(!lines.verticalLineVisible)
        }
        #expect(result[0].verticalLineX == -50)
        #expect(result[0].horizontalLineY == 2000)
    }

    @Test("single display: both lines visible, local positions equal global offset")
    func singleDisplay() {
        let result = GeometryLayer.lines(
            forCursor: CGPoint(x: 800, y: 600),
            displayFrames: [mainDisplay]
        )

        let lines = try! #require(result.first)
        #expect(lines.horizontalLineVisible)
        #expect(lines.verticalLineVisible)
        #expect(lines.verticalLineX == 800)
        #expect(lines.horizontalLineY == 600)
    }

    @Test("multi-display: vertical line stays on cursor's display, horizontal spans both")
    func multiDisplayHorizontalSpan() {
        let right = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let frames = [mainDisplay, right]
        // Cursor on the left display, mid-height shared by both.
        let result = GeometryLayer.lines(forCursor: CGPoint(x: 500, y: 540), displayFrames: frames)

        // Horizontal line crosses both displays at the shared y.
        #expect(result[0].horizontalLineVisible)
        #expect(result[1].horizontalLineVisible)
        #expect(result[0].horizontalLineY == 540)
        #expect(result[1].horizontalLineY == 540)

        // Vertical line only on the display containing the cursor's x.
        #expect(result[0].verticalLineVisible)
        #expect(!result[1].verticalLineVisible)
        #expect(result[1].verticalLineX == -1420)
    }

    @Test("vertically stacked displays: vertical line spans both, horizontal stays on one")
    func multiDisplayVerticalSpan() {
        let top = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let frames = [mainDisplay, top]
        // Cursor on the bottom display, x shared by both.
        let result = GeometryLayer.lines(forCursor: CGPoint(x: 960, y: 200), displayFrames: frames)

        #expect(result[0].verticalLineVisible)
        #expect(result[1].verticalLineVisible)
        #expect(result[0].verticalLineX == 960)
        #expect(result[1].verticalLineX == 960)

        #expect(result[0].horizontalLineVisible)
        #expect(!result[1].horizontalLineVisible)
        #expect(result[1].horizontalLineY == -880)
    }

    @Test("negative-origin frame: local positions are offset from the frame origin")
    func negativeOriginFrame() {
        let left = CGRect(x: -1920, y: -300, width: 1920, height: 1080)
        let result = GeometryLayer.lines(
            forCursor: CGPoint(x: -1000, y: 100),
            displayFrames: [left]
        )

        let lines = try! #require(result.first)
        #expect(lines.verticalLineVisible)
        #expect(lines.horizontalLineVisible)
        #expect(lines.verticalLineX == 920)
        #expect(lines.horizontalLineY == 400)
    }

    @Test("cursor exactly on a shared bezel edge lights up both neighbours")
    func sharedEdgeInclusive() {
        let right = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let result = GeometryLayer.lines(
            forCursor: CGPoint(x: 1920, y: 540),
            displayFrames: [mainDisplay, right]
        )
        #expect(result[0].verticalLineVisible)
        #expect(result[1].verticalLineVisible)
    }

    @Test("2x2 grid: the display sharing neither axis with the cursor shows no line")
    func diagonalNeighborHasNoLine() {
        let bottomLeft = mainDisplay
        let bottomRight = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let topLeft = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let topRight = CGRect(x: 1920, y: 1080, width: 1920, height: 1080)
        let frames = [bottomLeft, bottomRight, topLeft, topRight]
        // Cursor on the bottom-left display.
        let result = GeometryLayer.lines(forCursor: CGPoint(x: 500, y: 300), displayFrames: frames)

        // Cursor's display: both lines.
        #expect(result[0].horizontalLineVisible)
        #expect(result[0].verticalLineVisible)
        // Same row (shares y): horizontal only.
        #expect(result[1].horizontalLineVisible)
        #expect(!result[1].verticalLineVisible)
        // Same column (shares x): vertical only.
        #expect(!result[2].horizontalLineVisible)
        #expect(result[2].verticalLineVisible)
        // Diagonal neighbour (shares neither): nothing.
        #expect(!result[3].horizontalLineVisible)
        #expect(!result[3].verticalLineVisible)
    }

    @Test("empty display set yields no lines")
    func noDisplays() {
        #expect(GeometryLayer.lines(forCursor: .zero, displayFrames: []).isEmpty)
    }
}
