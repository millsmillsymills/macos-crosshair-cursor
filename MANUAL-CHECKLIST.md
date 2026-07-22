# Manual Verification Checklist

Covers the system- and visual-level behaviour that `swift test` cannot exercise
(see PLAN.md "Testing"). Run from a release bundle so `LSUIElement` and
`SMAppService` behave like the shipped app:

```sh
./build.sh
open Crosshair.app
```

The unit-tested layers (`GeometryLayer`, `Settings`) are covered by `swift test`
and are out of scope here.

## Rendering crispness per display

- [ ] On each attached display, the horizontal and vertical lines render as thin,
      hairline-sharp segments (no blur or doubling). Verify on both a Retina and a
      non-Retina display if available — `NSHighResolutionCapable` is set, so each
      Overlay Window should draw at its own display's backing scale.
- [ ] Increase Thickness in Preferences and confirm the line widens evenly on
      every display.

## Click-through

- [ ] With the Crosshair shown, click and drag windows, buttons, and the Desktop
      directly under the lines. Every click reaches the app underneath — the
      Overlay Windows never intercept the mouse (`ignoresMouseEvents`).
- [ ] Select text or icons that sit beneath the intersection point; selection
      works normally.

## Hotkey toggle

- [ ] Press ⌥⌘X. The Crosshair hides. Press again — it reappears.
- [ ] The menu-bar "Show Crosshair" checkmark mirrors the current state after each
      hotkey press.
- [ ] The menu-bar "Show Crosshair" item toggles the Crosshair on its own, and its
      effect stays in sync with the hotkey.

## Crosshair continuity across bezels

- [ ] Move the cursor slowly across the seam between two side-by-side displays. The
      horizontal line is continuous across both displays at the shared height; the
      vertical line tracks the cursor onto the display it currently occupies.
- [ ] Repeat for vertically stacked displays: the vertical line spans both at the
      shared x.
- [ ] Park the cursor exactly on a shared bezel edge and confirm both neighbouring
      displays light up (inclusive bounds).
- [ ] Arrange displays with an offset (not edge-aligned) and confirm a line simply
      stops at a display that does not share the cursor's row/column.

## Hot-plug / rearrange

- [ ] Unplug an external display while the Crosshair is shown. Its Overlay Window
      disappears; the remaining displays keep a correct Crosshair.
- [ ] Plug the display back in. A new Overlay Window appears and immediately tracks
      the cursor (debounced ~100 ms Rebuild).
- [ ] Rearrange displays in System Settings > Displays (drag one to a new side).
      After the change settles, the Crosshair spans correctly across the new layout.
- [ ] Rapidly toggle a display a few times; only a single coalesced Rebuild should
      result (no flicker storm, no crash).

## Zero / single display

- [ ] Put all displays to sleep or disconnect every external display so only the
      built-in (or none) remains. With zero active displays there are no Overlay
      Windows and the app stays alive. When a display returns, the Crosshair comes
      back automatically.
- [ ] On a single-display Mac, confirm normal tracking with no special-casing and
      no crash.

## Spaces

- [ ] Switch to another Space (Mission Control / swipe). The Crosshair is present
      on the new Space too (`canJoinAllSpaces` + `.stationary`).
- [ ] Open a full-screen Space for another app. The Crosshair appears over that
      app's full-screen Space too (`.fullScreenAuxiliary`).

## Launch at login

- [ ] In Preferences, enable "Launch at login". Confirm the app appears under
      System Settings > General > Login Items.
- [ ] Disable it; confirm it is removed from Login Items.
- [ ] Log out and back in with it enabled; the menu-bar agent starts automatically.
- [ ] Note: registration only succeeds from a properly bundled, signed
      `Crosshair.app` (via `build.sh`), not a bare `swift run`. If registration
      fails, the toggle reverts itself and the failure is logged — no crash.

## Hotkey-conflict alert

- [ ] Launch another app that registers ⌥⌘X first, then launch Crosshair. A
      non-fatal warning alert appears at startup explaining the hotkey is
      unavailable.
- [ ] The menu shows a disabled "Hotkey ⌥⌘X unavailable" note, and the
      "Show Crosshair" menu item still toggles the Crosshair.

## Config clamping (end-to-end)

- [ ] Corrupt or clear the stored settings
      (`defaults delete com.millsymills.crosshair`), relaunch, and confirm the app comes
      up with clamped defaults (red, 60% opacity, 1 pt) rather than crashing.
- [ ] In Preferences, the Opacity slider is bounded to 0–100 and the Thickness
      stepper to its minimum of 1 pt.
