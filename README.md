# Crosshair

A macOS menu-bar utility that draws a full-screen crosshair following the mouse
cursor across all displays — one line spanning the full width and one the full
height of the display arrangement, intersecting at the cursor. Useful for
locating the cursor on large multi-monitor setups and for checking monitor
alignment.

Native Swift + AppKit, built with SwiftPM (no Xcode project). No third-party
dependencies, no network access, and no macOS permission prompts — cursor
tracking uses a plain global `NSEvent` monitor, not an event tap.

## Features

- Crosshair spanning all connected displays, tracking the cursor live
- Toggle via the menu-bar item or the global hotkey ⌥⌘X
- Adjustable color, opacity, and thickness (default: red, 60%, 1 pt)
- Click-through overlay that joins all Spaces and stays below the menu bar
- Optional launch at login
- Handles display hot-plug and rearrangement

## Requirements

- macOS 13.0 or later
- Swift toolchain (Xcode or Command Line Tools) to build

## Build

```sh
./build.sh
```

This builds the release binary and assembles a self-contained `Crosshair.app`
in the repo root. Launch it with `open Crosshair.app`.

## Test

```sh
./test.sh
```

Runs the unit tests for the pure geometry and settings logic. System-level and
visual behaviour is covered by [MANUAL-CHECKLIST.md](./MANUAL-CHECKLIST.md).

## Code signing caveat

`build.sh` ad-hoc signs the bundle (`codesign -s -`), which is fine for an app
you build yourself. A pre-built `Crosshair.app` copied from another machine
will be blocked by Gatekeeper because it is not notarized — build from source
instead.

## Documentation

- [CONTEXT.md](./CONTEXT.md) — domain language
- [PLAN.md](./PLAN.md) — design decisions and architecture
- [docs/adr/](./docs/adr/) — architecture decision records

## License

[MIT](./LICENSE)
