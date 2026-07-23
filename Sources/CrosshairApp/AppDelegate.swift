import AppKit
import CrosshairCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var overlayController: OverlayController?
    private var hotKeyManager: HotKeyManager?
    private var settingsModel: SettingsModel?
    private var preferencesController: PreferencesController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders: the bundle's Info.plist carries LSUIElement=true,
        // but setting the policy here also makes the bare binary run as a
        // Dock-less menu-bar agent.
        NSApp.setActivationPolicy(.accessory)

        let version = Bundle.main
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "unbundled"
        Log.app.notice("launching Crosshair \(version, privacy: .public)")

        let settings = Self.loadSettings(from: UserDefaults.standard)
        let overlayController = OverlayController(settings: settings)
        self.overlayController = overlayController
        let trackingInstalled = overlayController.start()

        let settingsModel = SettingsModel(
            settings: settings,
            store: UserDefaults.standard,
            loginItem: LoginItemController()
        ) { [weak self] newSettings in
            self?.overlayController?.apply(settings: newSettings)
        }
        self.settingsModel = settingsModel
        preferencesController = PreferencesController(model: settingsModel)

        statusItemController = StatusItemController(
            visible: overlayController.visible,
            onToggle: { [weak self] in self?.toggleCrosshair() },
            onOpenPreferences: { [weak self] in self?.preferencesController?.show() }
        )

        let hotKeyManager = HotKeyManager { [weak self] in
            self?.toggleCrosshair()
        }
        self.hotKeyManager = hotKeyManager
        if !hotKeyManager.register() {
            statusItemController?.showHotKeyConflict()
            presentHotKeyConflictAlert()
        }

        if !trackingInstalled {
            statusItemController?.showTrackingFailure()
            presentTrackingFailureAlert()
        }
    }

    /// Loads stored settings, falling back to defaults — loudly, so a corrupt
    /// blob (which silently discards the user's customizations) is visible in
    /// the unified log instead of looking like a spontaneous reset. The corrupt
    /// blob is preserved under a backup key first; otherwise the next
    /// Preferences edit would overwrite the only copy.
    private static func loadSettings(from store: SettingsStore) -> Settings {
        do {
            guard let stored = try Settings.loadStored(from: store) else {
                Log.settings.notice("no stored settings; using defaults")
                return .default
            }
            return stored
        } catch {
            let backedUpBytes = Settings.backUpStoredBlob(in: store) ?? 0
            Log.settings.error(
                """
                stored settings are corrupt, reverting to defaults; backed up \
                \(backedUpBytes) bytes to \(Settings.corruptBackupKey, privacy: .public): \
                \(error, privacy: .public)
                """
            )
            return .default
        }
    }

    private func toggleCrosshair() {
        guard let overlayController else { return }
        statusItemController?.setVisible(overlayController.toggleVisibility())
    }

    /// Non-fatal heads-up that ⌥⌘X is already claimed (PLAN edge case #15). The
    /// menu's Show Crosshair item still toggles the Crosshair, so this only
    /// informs; it never blocks startup.
    private func presentHotKeyConflictAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Crosshair hotkey unavailable"
        alert.informativeText = """
            Another app is already using ⌥⌘X, so the global toggle hotkey is \
            disabled. You can still show or hide the Crosshair from the menu-bar \
            icon.
            """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Non-fatal heads-up that the mouse monitors failed to install, so the
    /// crosshair will not follow the cursor. Without this the only trace is a
    /// log line and the crosshair just looks frozen.
    private func presentTrackingFailureAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Crosshair can't track the cursor"
        alert.informativeText = """
            The mouse monitor failed to start, so the crosshair won't follow \
            the cursor. Try quitting and relaunching Crosshair.
            """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
