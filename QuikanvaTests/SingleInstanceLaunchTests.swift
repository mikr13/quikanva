import XCTest
@testable import Quikanva

final class SingleInstanceLaunchTests: XCTestCase {
    func testNewerSameBundleProcessActivatesExistingProcessAndTerminates() {
        let action = SingleInstanceLaunch.action(
            currentProcess: .init(
                processIdentifier: 102,
                bundleIdentifier: "com.mihirpandey.quikanva",
                launchDate: Date(timeIntervalSince1970: 2)
            ),
            runningProcesses: [
                .init(
                    processIdentifier: 101,
                    bundleIdentifier: "com.mihirpandey.quikanva",
                    launchDate: Date(timeIntervalSince1970: 1)
                ),
                .init(
                    processIdentifier: 102,
                    bundleIdentifier: "com.mihirpandey.quikanva",
                    launchDate: Date(timeIntervalSince1970: 2)
                ),
            ]
        )

        XCTAssertEqual(action, .activateAndTerminate(processIdentifier: 101))
    }
}
