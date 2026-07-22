# Logging and error-handling standards

Crosshair logs to the macOS unified log under the subsystem
`com.millsymills.crosshair` via `os.Logger` handles in
`Sources/CrosshairApp/Log.swift`. There is no app-managed log file; the unified
log gives retention, levels, and offline collection for free.

## Categories

| Category   | Covers |
|------------|--------|
| `app`      | Launch, activation policy, app-level lifecycle |
| `overlay`  | Overlay window set: rebuilds, screen parameter changes, screen wake, visibility toggles, window numbers |
| `tracking` | The global mouse-event monitor lifecycle |
| `settings` | Settings load/save, launch-at-login registration |
| `hotkey`   | Carbon hotkey handler install/registration |

## Level policy

- **error** — an operation failed. The message must name the operation, the
  input or state that failed, and the fallback taken. Every fallback path logs
  at this level; a fallback that isn't logged is a silent failure.
- **notice** (persisted by default) — state transitions worth having in a
  postmortem: rebuilds with the resulting screen/window list, visibility
  changes, monitor/hotkey registration. Keep these low-rate; they survive in
  `log collect` archives without any configuration.
- **debug** — high-frequency detail, visible only when streaming. Never log
  per-cursor-move events at any level; at ~60 events/sec they drown the log
  and cost more than they tell.

Mark non-sensitive interpolations `privacy: .public` (screen frames, window
numbers, error descriptions). Exported logs otherwise redact them to
`<private>`, which is exactly where diagnostic value dies.

## Error-handling rules

- No silent `try?` and no empty `catch`. Either propagate the error or handle
  it with a logged fallback.
- Core (`CrosshairCore`) stays logging-free: it surfaces failures via `throws`
  or `nil` returns and the app layer decides how to log and recover. This keeps
  Core pure and testable.
- Degraded modes must be observable: if a feature is disabled at runtime
  (hotkey conflict, failed event monitor), log at error level and surface it in
  the UI when the user would otherwise wonder why nothing happens.

## Collecting logs

```sh
# Everything the app logged, live
log stream --predicate 'subsystem == "com.millsymills.crosshair"' --info --debug

# Retrospective, from the local store or a .logarchive
log show --predicate 'subsystem == "com.millsymills.crosshair"' --info --style syslog

# Self-contained archive for offline analysis (retention is ~7 days)
log collect --last 1d --output crosshair.logarchive
```

When chasing display glitches, also capture the window server side:

```sh
log show --predicate 'process == "WindowServer" OR process == "Crosshair"' \
  --start '<time>' --end '<time>' --info --style syslog
```
