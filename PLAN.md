# macOS Crosshair Cursor — Implementation Plan

A menu-bar utility that draws a full-screen crosshair following the mouse cursor
across all displays, to locate the cursor on large multi-monitor setups and to
aid monitor-arrangement alignment. See [CONTEXT.md](./CONTEXT.md) for domain
language and [docs/adr/](./docs/adr/) for the load-bearing decisions.

## Resolved decisions

| # | Branch | Decision |
|---|--------|----------|
| 1 | Stack | Native Swift + AppKit, built with SwiftPM (no Xcode project) — ADR-0001 |
| 2 | Form factor | Menu-bar agent (`LSUIElement`), no Dock icon |
| 3 | Overlay architecture | One Overlay Window per `NSScreen` — ADR-0002 |
| 4 | Tracking | Global `NSEvent` monitor on mouse-moved + dragged, permission-free — ADR-0003 |
| 5 | Hotkey | Carbon `RegisterEventHotKey`, fixed default ⌥⌘X, hand-rolled — ADR-0003 |
| 6 | Elevation | Float above normal windows, join all Spaces, below menu bar; not over other apps' full-screen |
| 7 | Appearance | Adjustable: color, opacity, thickness. Default: red, 60%, 1 pt |
| 8 | Alignment aid | Emergent from the spanning crosshair — no dedicated feature |
| 9 | Preferences | Small SwiftUI Preferences window via `NSHostingController`; menu = Toggle / Preferences… / Quit |
| 10 | Launch at login | `SMAppService`, Preferences checkbox, default off |
| 11 | Hot-plug | Observe `didChangeScreenParametersNotification`, debounced full Rebuild |
| 12 | Packaging | SPM executable + `build.sh` assembling the `.app` bundle |
| 13 | Distribution | Ad-hoc signed (`codesign -s -`) for local use; Developer ID + notarization deferrable |
| 14 | Testing | Unit-test pure Geometry layer + config; manual checklist for system/visual |
| 15 | Error handling | Graceful degradation; fail-fast message only on hotkey conflict |

## Architecture

```
AppDelegate (NSApplication, LSUIElement)
├── StatusItemController        — NSStatusItem, menu (Toggle / Preferences… / Quit)
├── HotKeyManager               — RegisterEventHotKey(⌥⌘X) → toggle; non-fatal on conflict
├── CursorTracker               — global NSEvent monitor → publishes global cursor point
├── OverlayController           — owns [OverlayWindow] (one per NSScreen)
│   ├── builds/Rebuilds on didChangeScreenParameters (debounced ~100ms)
│   └── on cursor move: maps point via GeometryLayer → updates each window's lines
├── OverlayWindow (NSWindow)    — borderless, transparent, ignoresMouseEvents,
│   └── CrosshairView (NSView)  — draws H + V line segments for this display
├── GeometryLayer (pure)        — (globalPoint, [displayFrame]) → per-window line specs   ← unit-tested
├── Settings (Codable)          — color, opacity, thickness, launchAtLogin; UserDefaults  ← unit-tested
└── PreferencesView (SwiftUI)   — color well, opacity slider, thickness stepper, hotkey label, login toggle
```

Key design constraint (from #14): **GeometryLayer takes display frames as input** and
never reads `NSScreen.screens` itself, so cursor→line mapping is verifiable in isolation.

## Build order (tracer-bullet slices)

1. **Skeleton + bundle.** `Package.swift`, `AppDelegate`, `LSUIElement` plist, `build.sh`
   producing an ad-hoc-signed `.app` that launches as a menu-bar item with a Quit menu.
2. **Static crosshair.** One OverlayWindow per screen drawing a fixed-position crosshair
   (verifies transparency, click-through, elevation, multi-display span).
3. **Live tracking.** CursorTracker + GeometryLayer → crosshair follows the mouse across displays.
4. **Toggle hotkey.** HotKeyManager ⌥⌘X show/hide; menu toggle mirrors it.
5. **Appearance.** Settings model + Preferences window (color/opacity/thickness), live-applied, persisted.
6. **Hot-plug.** Debounced Rebuild on display changes; verify dock/undock and rearrange.
7. **Launch at login.** `SMAppService` checkbox.
8. **Edge cases + tests.** Hotkey-conflict alert, zero/one display, config clamping; `swift test` for GeometryLayer + Settings; fill out manual checklist.

## Testing

- **Unit (`swift test`):** GeometryLayer (point + frames → line specs, including off-screen
  and multi-display crossings), Settings (encode/decode, opacity 0–100 & thickness clamping, defaults).
- **Manual checklist:** rendering crispness per display, click-through, hotkey toggle, crosshair
  continuity across bezels, hot-plug/rearrange, Spaces, launch-at-login, hotkey-conflict alert.

## Edge cases (#15)

- Hotkey already taken → non-fatal alert + menu note; menu toggle still works.
- Zero displays / all asleep → no windows; Rebuild when displays return.
- Single display → no special case.
- Cursor captured/hidden → crosshair stops updating (accepted, ADR-0003).
- Display-change bursts → debounce ~100 ms → single Rebuild.
- Corrupt `UserDefaults` → fall back to clamped defaults.

## Deferred (explicitly not in v1)

- In-app hotkey recorder / configurable combo (would add `KeyboardShortcuts` dep).
- Live coordinate readout / grid / freeze-line alignment mode.
- Dashed lines, center gap/dot, per-axis enable.
- Developer ID signing + notarization for public distribution.
- Visibility inside other apps' full-screen Spaces.
