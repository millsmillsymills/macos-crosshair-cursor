import ServiceManagement

/// Drives launch-at-login through `SMAppService.mainApp`, which needs no helper
/// bundle or privileged login-item API. Errors propagate so the caller can keep
/// the UI honest; registration failure is non-fatal.
@MainActor
struct LoginItemController {
    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
