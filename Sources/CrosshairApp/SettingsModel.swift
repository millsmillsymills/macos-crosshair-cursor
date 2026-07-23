import AppKit
import CrosshairCore

/// Bridges the AppKit-free `RGBAColor` from Core to `NSColor` and back. Core
/// stays free of AppKit; this conversion lives only in the app layer.
extension RGBAColor {
    init(_ nsColor: NSColor) {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }
}

extension NSColor {
    convenience init(_ rgba: RGBAColor) {
        self.init(
            srgbRed: CGFloat(rgba.red),
            green: CGFloat(rgba.green),
            blue: CGFloat(rgba.blue),
            alpha: CGFloat(rgba.alpha)
        )
    }
}

/// The Preferences window's editable view model. Holds the live UI state, builds
/// a clamped `Settings` from it on every edit, persists it, and pushes it to the
/// Crosshair via `onChange`. Launch-at-login edits also drive `SMAppService` and
/// revert the toggle if registration fails.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var color: NSColor { didSet { commit() } }
    @Published var opacityPercent: Double { didSet { commit() } }
    @Published var thicknessPoints: Double { didSet { commit() } }
    @Published var launchAtLogin: Bool { didSet { applyLaunchAtLogin(oldValue: oldValue) } }
    @Published private(set) var saveFailed = false

    let hotKeyLabel = "⌥⌘X"

    private let store: SettingsStore
    private let loginItem: LoginItemController
    private let onChange: (Settings) -> Void
    private var isReverting = false

    init(
        settings: Settings,
        store: SettingsStore,
        loginItem: LoginItemController,
        onChange: @escaping (Settings) -> Void
    ) {
        self.store = store
        self.loginItem = loginItem
        self.onChange = onChange
        self.color = NSColor(settings.crosshairColor)
        self.opacityPercent = Double(settings.opacityPercent)
        self.thicknessPoints = settings.thicknessPoints
        self.launchAtLogin = settings.launchAtLogin
    }

    private func makeSettings() -> Settings {
        Settings(
            crosshairColor: RGBAColor(color),
            opacityPercent: Int(opacityPercent.rounded()),
            thicknessPoints: thicknessPoints,
            launchAtLogin: launchAtLogin
        )
    }

    private func commit() {
        guard !isReverting else { return }
        let settings = makeSettings()
        do {
            try settings.save(to: store)
            saveFailed = false
        } catch {
            Log.settings.error(
                "settings not persisted; change won't survive relaunch: \(error, privacy: .public)"
            )
            saveFailed = true
        }
        onChange(settings)
    }

    private func applyLaunchAtLogin(oldValue: Bool) {
        guard !isReverting else { return }
        do {
            try loginItem.setEnabled(launchAtLogin)
            commit()
        } catch {
            let enabled = launchAtLogin
            Log.settings.error(
                "launch-at-login=\(enabled) failed; reverting: \(error, privacy: .public)"
            )
            isReverting = true
            launchAtLogin = oldValue
            isReverting = false
        }
    }
}
