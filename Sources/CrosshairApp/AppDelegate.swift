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

        let settings = Settings.load(from: UserDefaults.standard)
        let overlayController = OverlayController(settings: settings)
        self.overlayController = overlayController
        overlayController.start()

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
}
