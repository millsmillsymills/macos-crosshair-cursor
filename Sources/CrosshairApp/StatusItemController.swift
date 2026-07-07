import AppKit

/// Owns the menu-bar agent's `NSStatusItem` and its menu
/// (Toggle / Preferences… / Quit). The Toggle item fires `onToggle` and carries
/// a checkmark mirroring whether the Crosshair is currently shown; Preferences…
/// fires `onOpenPreferences`.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let toggleItem: NSMenuItem
    private let onToggle: @MainActor () -> Void
    private let onOpenPreferences: @MainActor () -> Void
    private var hotKeyConflictItem: NSMenuItem?

    init(
        visible: Bool,
        onToggle: @escaping @MainActor () -> Void,
        onOpenPreferences: @escaping @MainActor () -> Void
    ) {
        self.onToggle = onToggle
        self.onOpenPreferences = onOpenPreferences
        self.toggleItem = NSMenuItem(
            title: "Show Crosshair",
            action: #selector(toggleCrosshair),
            keyEquivalent: ""
        )
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "plus.viewfinder",
                accessibilityDescription: "Crosshair"
            )
            button.image?.isTemplate = true
        }
        statusItem.menu = makeMenu()
        setVisible(visible)
    }

    /// Mirrors the Crosshair's shown/hidden state in the menu's checkmark.
    func setVisible(_ visible: Bool) {
        toggleItem.state = visible ? .on : .off
    }

    /// Adds a disabled note to the menu when ⌥⌘X could not be registered, so the
    /// user can see why the hotkey does nothing. The menu toggle is unaffected.
    func showHotKeyConflict() {
        guard hotKeyConflictItem == nil, let menu = statusItem.menu else { return }
        let note = NSMenuItem(
            title: "Hotkey ⌥⌘X unavailable (in use by another app)",
            action: nil,
            keyEquivalent: ""
        )
        note.isEnabled = false
        menu.insertItem(note, at: menu.index(of: toggleItem) + 1)
        hotKeyConflictItem = note
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        toggleItem.target = self
        menu.addItem(toggleItem)

        let preferencesItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Crosshair",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleCrosshair() {
        onToggle()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }
}
