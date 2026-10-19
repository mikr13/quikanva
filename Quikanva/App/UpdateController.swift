import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject {
    static let shared = UpdateController()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    /// Includes updates downloaded silently and waiting for the app to quit.
    @Published private(set) var availableUpdateVersion: String?

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    override init() {
        super.init()
        let updater = updaterController.updater
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloadsUpdates)
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    func start() {
        updaterController.startUpdater()
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
    }
}

extension UpdateController: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // Automatic downloads can finish without ever presenting the standard user driver.
        availableUpdateVersion = item.displayVersionString
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        availableUpdateVersion = nil
    }
}

// Quikanva is a menu bar app, so a scheduled update alert opens behind other apps.
// The menu bar menu offers the pending update until the user looks at it.
extension UpdateController: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        if !state.userInitiated {
            availableUpdateVersion = update.displayVersionString
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableUpdateVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableUpdateVersion = nil
    }
}
