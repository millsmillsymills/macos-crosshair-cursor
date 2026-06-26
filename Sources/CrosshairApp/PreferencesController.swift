import AppKit
import SwiftUI

/// Lazily builds and shows the Preferences window that hosts `PreferencesView`
/// via `NSHostingController`. The window is kept alive across closes so reopening
/// is instant; as an accessory (Dock-less) agent we must activate the app to
/// bring the window forward and make it key.
@MainActor
final class PreferencesController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(model: model)))
        window.title = "Crosshair Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
