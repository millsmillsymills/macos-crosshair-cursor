import Foundation

/// An AppKit-free RGBA colour with components in 0...1, so Core never depends on
/// `NSColor`. The app layer converts this to/from `NSColor` at the boundary.
public struct RGBAColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = Self.clampUnit(red)
        self.green = Self.clampUnit(green)
        self.blue = Self.clampUnit(blue)
        self.alpha = Self.clampUnit(alpha)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decode(Double.self, forKey: .alpha)
        )
    }

    public static let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

    private static func clampUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// User-adjustable appearance and behaviour, persisted as JSON in a
/// `SettingsStore`. Out-of-range opacity and thickness are clamped at every
/// entry point so an invalid `Settings` value cannot exist.
public struct Settings: Codable, Equatable, Sendable {
    public let crosshairColor: RGBAColor
    public let opacityPercent: Int
    public let thicknessPoints: Double
    public let launchAtLogin: Bool

    public static let minThicknessPoints: Double = 1

    public init(
        crosshairColor: RGBAColor,
        opacityPercent: Int,
        thicknessPoints: Double,
        launchAtLogin: Bool
    ) {
        self.crosshairColor = crosshairColor
        self.opacityPercent = Self.clampOpacity(opacityPercent)
        self.thicknessPoints = Self.clampThickness(thicknessPoints)
        self.launchAtLogin = launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            crosshairColor: try container.decode(RGBAColor.self, forKey: .crosshairColor),
            opacityPercent: try container.decode(Int.self, forKey: .opacityPercent),
            thicknessPoints: try container.decode(Double.self, forKey: .thicknessPoints),
            launchAtLogin: try container.decode(Bool.self, forKey: .launchAtLogin)
        )
    }

    public static let `default` = Settings(
        crosshairColor: .red,
        opacityPercent: 60,
        thicknessPoints: 1,
        launchAtLogin: false
    )

    private static func clampOpacity(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    private static func clampThickness(_ value: Double) -> Double {
        // max(NaN, 1) returns NaN, and JSONEncoder rejects non-finite Doubles,
        // so a non-finite value here would make Settings permanently unsaveable.
        guard value.isFinite else { return minThicknessPoints }
        return max(value, minThicknessPoints)
    }
}

/// Persistence boundary for `Settings`, so tests run against an in-memory stub
/// instead of the real `UserDefaults`.
public protocol SettingsStore {
    func settingsData(forKey key: String) -> Data?
    func setSettingsData(_ data: Data?, forKey key: String)
}

extension UserDefaults: SettingsStore {
    public func settingsData(forKey key: String) -> Data? {
        data(forKey: key)
    }

    public func setSettingsData(_ data: Data?, forKey key: String) {
        set(data, forKey: key)
    }
}

extension Settings {
    public static let storageKey = "com.millsymills.crosshair.settings"

    /// Loads the stored settings, or `nil` when nothing is stored yet. Throws
    /// when a stored blob exists but cannot be decoded, so the caller can log
    /// the corruption before falling back. Decoded values are clamped via
    /// `init(from:)`.
    public static func loadStored(from store: SettingsStore) throws -> Settings? {
        guard let data = store.settingsData(forKey: storageKey) else { return nil }
        return try JSONDecoder().decode(Settings.self, from: data)
    }

    public func save(to store: SettingsStore) throws {
        store.setSettingsData(try JSONEncoder().encode(self), forKey: Self.storageKey)
    }
}
