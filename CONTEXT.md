# macOS Crosshair Cursor

A menu-bar utility that draws a full-screen crosshair following the mouse cursor across all displays, to make the cursor easy to locate on large multi-monitor setups and to assist with monitor-arrangement alignment.

## Language

**Crosshair**:
The pair of thin lines — one spanning the full width, one the full height of the display arrangement — that intersect at the cursor's current position.
_Avoid_: Reticle, guides, lines

**Overlay Window**:
A borderless, transparent, click-through window that draws the portion of the **Crosshair** crossing a single display. There is exactly one per `NSScreen`.
_Avoid_: Layer, canvas, surface

**Tracking**:
Observing the global cursor position (permission-free, via a global `NSEvent` monitor on mouse-moved + dragged) to reposition the **Crosshair**.
_Avoid_: Listening, hooking, watching

**Menu-bar agent**:
The app itself: a `LSUIElement` process with a status-bar item and no Dock icon, which owns the **Overlay Windows** and the toggle.

**Geometry layer**:
The pure, side-effect-free logic that maps a global cursor point + a set of display frames to each **Overlay Window**'s local line positions. Takes display frames as *input* (never reads `NSScreen.screens` itself) so it is unit-testable.

**Rebuild**:
Tearing down and recreating the full **Overlay Window** set in response to a display configuration change (`didChangeScreenParametersNotification`), debounced to coalesce bursts.

## Relationships

- The **Menu-bar agent** owns one **Overlay Window** per attached display
- **Tracking** drives the position of the **Crosshair** drawn across all **Overlay Windows**
- Display hot-plug / rearrangement adds or removes **Overlay Windows**

## Flagged ambiguities

- (none yet)
