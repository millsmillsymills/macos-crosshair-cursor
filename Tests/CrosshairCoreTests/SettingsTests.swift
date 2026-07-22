import Foundation
import Testing
@testable import CrosshairCore

private final class InMemoryStore: SettingsStore {
    private var storage: [String: Data] = [:]

    func settingsData(forKey key: String) -> Data? {
        storage[key]
    }

    func setSettingsData(_ data: Data?, forKey key: String) {
        storage[key] = data
    }

    func writeRaw(_ data: Data, forKey key: String) {
        storage[key] = data
    }
}

@Suite("Settings")
struct SettingsTests {
    @Test("defaults are red, 60%, 1pt, login off")
    func defaults() {
        let settings = Settings.default
        #expect(settings.crosshairColor == .red)
        #expect(settings.opacityPercent == 60)
        #expect(settings.thicknessPoints == 1)
        #expect(!settings.launchAtLogin)
    }

    @Test("encode/decode round-trips through a store")
    func roundTrip() throws {
        let store = InMemoryStore()
        let original = Settings(
            crosshairColor: RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1),
            opacityPercent: 75,
            thicknessPoints: 3,
            launchAtLogin: true
        )
        try original.save(to: store)
        #expect(try Settings.loadStored(from: store) == original)
    }

    @Test("opacity clamps to 0...100 at and beyond the boundaries", arguments: [
        (-10, 0), (0, 0), (100, 100), (150, 100),
    ])
    func opacityClamping(input: Int, expected: Int) {
        let settings = Settings(
            crosshairColor: .red,
            opacityPercent: input,
            thicknessPoints: 1,
            launchAtLogin: false
        )
        #expect(settings.opacityPercent == expected)
    }

    @Test("thickness clamps up to the 1pt minimum")
    func thicknessClamping() {
        #expect(Settings(crosshairColor: .red, opacityPercent: 60,
                         thicknessPoints: 0, launchAtLogin: false).thicknessPoints == 1)
        #expect(Settings(crosshairColor: .red, opacityPercent: 60,
                         thicknessPoints: -5, launchAtLogin: false).thicknessPoints == 1)
        #expect(Settings(crosshairColor: .red, opacityPercent: 60,
                         thicknessPoints: 4.5, launchAtLogin: false).thicknessPoints == 4.5)
    }

    @Test("decoding out-of-range JSON clamps rather than throwing")
    func decodeClamps() throws {
        let json = Data("""
        {"crosshairColor":{"red":1,"green":0,"blue":0,"alpha":1},
         "opacityPercent":999,"thicknessPoints":0,"launchAtLogin":false}
        """.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: json)
        #expect(decoded.opacityPercent == 100)
        #expect(decoded.thicknessPoints == 1)
    }

    @Test("missing stored data loads as nil")
    func missingDataLoadsNil() throws {
        #expect(try Settings.loadStored(from: InMemoryStore()) == nil)
    }

    @Test("corrupt stored data throws instead of silently succeeding")
    func corruptDataThrows() {
        let store = InMemoryStore()
        store.writeRaw(Data("not json".utf8), forKey: Settings.storageKey)
        #expect(throws: DecodingError.self) {
            try Settings.loadStored(from: store)
        }
    }

    @Test("color components clamp into 0...1")
    func colorClamping() {
        let color = RGBAColor(red: 2, green: -1, blue: 0.5, alpha: 9)
        #expect(color.red == 1)
        #expect(color.green == 0)
        #expect(color.blue == 0.5)
        #expect(color.alpha == 1)
    }
}
