import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let currentProcess = SingleInstanceLaunch.RunningProcess(
                processIdentifier: ProcessInfo.processInfo.processIdentifier,
                bundleIdentifier: Bundle.main.bundleIdentifier,
                launchDate: NSRunningApplication.current.launchDate
            )
            let runningProcesses = NSWorkspace.shared.runningApplications.map {
                SingleInstanceLaunch.RunningProcess(
                    processIdentifier: $0.processIdentifier,
                    bundleIdentifier: $0.bundleIdentifier,
                    launchDate: $0.launchDate
                )
            }

            if case let .activateAndTerminate(processIdentifier) = SingleInstanceLaunch.action(
                currentProcess: currentProcess,
                runningProcesses: runningProcesses
            ) {
                if let existingApplication = NSWorkspace.shared.runningApplications
                    .first(where: { $0.processIdentifier == processIdentifier }) {
                    existingApplication.activate(options: [.activateIgnoringOtherApps])
                }
                NSApp.terminate(nil)
                return
            }
        }

        NSApp.setActivationPolicy(.accessory)
        CanvasWindowManager.shared.prewarm()
        KeyboardShortcuts.onKeyUp(for: .newCanvas) {
            CanvasWindowManager.shared.newCanvas()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            CanvasWindowManager.shared.route(url)
        }
    }
}

enum SingleInstanceLaunch {
    struct RunningProcess: Equatable {
        let processIdentifier: Int32
        let bundleIdentifier: String?
        let launchDate: Date?
    }

    enum Action: Equatable {
        case continueLaunching
        case activateAndTerminate(processIdentifier: Int32)
    }

    static func action(currentProcess: RunningProcess,
                       runningProcesses: [RunningProcess]) -> Action {
        guard let bundleIdentifier = currentProcess.bundleIdentifier else {
            return .continueLaunching
        }

        let matchingProcess = runningProcesses
            .filter {
                $0.processIdentifier != currentProcess.processIdentifier &&
                    $0.bundleIdentifier == bundleIdentifier
            }
            .min(by: isEarlier(_:_:))

        guard let matchingProcess, isEarlier(matchingProcess, currentProcess) else {
            return .continueLaunching
        }

        return .activateAndTerminate(processIdentifier: matchingProcess.processIdentifier)
    }

    private static func isEarlier(_ lhs: RunningProcess, _ rhs: RunningProcess) -> Bool {
        switch (lhs.launchDate, rhs.launchDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        default:
            return lhs.processIdentifier < rhs.processIdentifier
        }
    }
}
