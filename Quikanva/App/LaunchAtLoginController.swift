import Combine
import ServiceManagement

protocol LaunchAtLoginService {
    var status: SMAppService.Status { get }

    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

struct SystemLaunchAtLoginService: LaunchAtLoginService {
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let service: any LaunchAtLoginService

    init(service: any LaunchAtLoginService = SystemLaunchAtLoginService()) {
        self.service = service
        status = service.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var statusMessage: String {
        switch status {
        case .notRegistered:
            "Quikanva will remain closed when you log in."
        case .enabled:
            "Quikanva will open automatically when you log in."
        case .requiresApproval:
            "Allow Quikanva in System Settings to finish enabling launch at login."
        case .notFound:
            "Launch at login is unavailable for this copy of Quikanva."
        @unknown default:
            "Launch at login status is unavailable."
        }
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        errorMessage = nil

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }

    func openSystemSettings() {
        service.openSystemSettingsLoginItems()
    }
}
