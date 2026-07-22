import os

/// Central unified-log handles, one per subsystem area, per docs/LOGGING.md.
/// Query everything the app logs with:
///
///     log show --predicate 'subsystem == "com.millsymills.crosshair"' --info --debug
enum Log {
    private static let subsystem = "com.millsymills.crosshair"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let tracking = Logger(subsystem: subsystem, category: "tracking")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
}
