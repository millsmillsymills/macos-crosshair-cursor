import AppKit
import Carbon.HIToolbox

/// Registers the fixed toggle hotkey (⌥⌘X) via Carbon `RegisterEventHotKey`,
/// which is system-wide and permission-free (ADR-0003) — unlike an `NSEvent`
/// keyDown monitor, which would trip the Accessibility prompt.
///
/// Registration is non-fatal: if the combo is already claimed by another app,
/// `register()` returns `false` so the caller can note the conflict, and the
/// menu toggle keeps working.
@MainActor
final class HotKeyManager {
    /// Four-char signature identifying this app's hotkeys to Carbon ("CHXr").
    private static let signature: OSType = 0x4348_5872

    private static let handler: EventHandlerUPP = { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated {
            manager.onToggle()
        }
        return noErr
    }

    private let onToggle: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(onToggle: @escaping @MainActor () -> Void) {
        self.onToggle = onToggle
    }

    /// Installs the Carbon handler and registers ⌥⌘X. Returns `false` (without
    /// crashing) if the combo is already taken or the handler can't install.
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            Log.hotkey.error("InstallEventHandler failed: OSStatus \(installStatus)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_X),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            Log.hotkey.error(
                "RegisterEventHotKey(⌥⌘X) failed (likely claimed): OSStatus \(registerStatus)"
            )
            removeHandler()
            return false
        }
        Log.hotkey.notice("registered global hotkey ⌥⌘X")
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        removeHandler()
    }

    private func removeHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    isolated deinit {
        unregister()
    }
}
