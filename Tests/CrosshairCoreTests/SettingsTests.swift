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

    @Test("non-finite thickness clamps to the minimum", arguments: [
        Double.nan, .infinity, -.infinity,
    ])
    func nonFiniteThicknessClamping(input: Double) {
        let settings = Settings(
            crosshairColor: .red,
            opacityPercent: 60,
            thicknessPoints: input,
            launchAtLogin: false
        )
        #expect(settings.thicknessPoints == Settings.minThicknessPoints)
    }

    @Test("settings built from NaN thickness still encode")
    func nanThicknessRemainsSaveable() throws {
        let store = InMemoryStore()
        let settings = Settings(
            crosshairColor: .red,
            opacityPercent: 60,
            thicknessPoints: .nan,
            launchAtLogin: false
        )
        try settings.save(to: store)
        #expect(try Settings.loadStored(from: store) == settings)
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

    @Test("backing up a corrupt blob copies it intact and reports its size")
    func corruptBlobBackup() {
        let store = InMemoryStore()
        let corrupt = Data("not json".utf8)
        store.writeRaw(corrupt, forKey: Settings.storageKey)

        #expect(Settings.backUpStoredBlob(in: store) == corrupt.count)
        #expect(store.settingsData(forKey: Settings.corruptBackupKey) == corrupt)
    }

    @Test("a later save overwrites the main key but not the backup")
    func backupSurvivesLaterSaves() throws {
        let store = InMemoryStore()
        let corrupt = Data("not json".utf8)
        store.writeRaw(corrupt, forKey: Settings.storageKey)
        _ = Settings.backUpStoredBlob(in: store)

        try Settings.default.save(to: store)

        #expect(store.settingsData(forKey: Settings.corruptBackupKey) == corrupt)
        #expect(try Settings.loadStored(from: store) == Settings.default)
    }

    @Test("backing up with nothing stored returns nil and writes no backup")
    func backupWithNothingStored() {
        let store = InMemoryStore()
        #expect(Settings.backUpStoredBlob(in: store) == nil)
        #expect(store.settingsData(forKey: Settings.corruptBackupKey) == nil)
    }

    @Test("a backup does not affect loading the main key")
    func backupDoesNotAffectLoad() throws {
        let store = InMemoryStore()
        store.writeRaw(Data("not json".utf8), forKey: Settings.corruptBackupKey)
        try Settings.default.save(to: store)
        #expect(try Settings.loadStored(from: store) == Settings.default)
    }

    @Test("color components clamp into 0...1")
    func colorClamping() {
        let color = RGBAColor(red: 2, green: -1, blue: 0.5, alpha: 9)
        #expect(color.red == 1)
        #expect(color.green == 0)
        #expect(color.blue == 0.5)
        #expect(color.alpha == 1)
    }

    @Test("non-finite color components clamp to finite values: NaN and -inf to 0, +inf to 1")
    func colorNonFiniteClamping() {
        let color = RGBAColor(red: .nan, green: -.infinity, blue: .infinity, alpha: .nan)
        #expect(color.red == 0)
        #expect(color.green == 0)
        #expect(color.blue == 1)
        #expect(color.alpha == 0)
    }

    @Test("settings built from non-finite color components round-trip through a store")
    func nonFiniteColorRoundTrips() throws {
        let store = InMemoryStore()
        let settings = Settings(
            crosshairColor: RGBAColor(red: .nan, green: .infinity, blue: -.infinity, alpha: .nan),
            opacityPercent: 60,
            thicknessPoints: 1,
            launchAtLogin: false
        )
        try settings.save(to: store)
        #expect(try Settings.loadStored(from: store) == settings)
    }
}
