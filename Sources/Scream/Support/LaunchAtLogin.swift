import ServiceManagement

enum LaunchAtLogin {
    @MainActor
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @MainActor
    static func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Launch at login change failed: \(error.localizedDescription)")
        }
    }
}
