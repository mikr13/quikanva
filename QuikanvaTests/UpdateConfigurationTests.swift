import XCTest
import Sparkle
@testable import Quikanva

final class UpdateConfigurationTests: XCTestCase {
    private let info = Bundle.main.infoDictionary ?? [:]

    func testBundleVersionMatchesMarketingVersion() {
        // Sparkle compares CFBundleVersion, and the appcast publishes the release version there.
        let bundleVersion = info["CFBundleVersion"] as? String
        XCTAssertNotNil(bundleVersion)
        XCTAssertEqual(bundleVersion, info["CFBundleShortVersionString"] as? String)
    }

    func testFeedURLPointsAtLatestGitHubReleaseAppcast() throws {
        let feedURL = try XCTUnwrap((info["SUFeedURL"] as? String).flatMap(URL.init(string:)))
        XCTAssertEqual(feedURL.scheme, "https")
        XCTAssertEqual(feedURL.host(), "github.com")
        XCTAssertTrue(feedURL.path().hasSuffix("/releases/latest/download/appcast.xml"))
    }

    func testPublicEdDSAKeyIsAnEd25519PublicKey() throws {
        let encodedKey = try XCTUnwrap(info["SUPublicEDKey"] as? String)
        let key = try XCTUnwrap(Data(base64Encoded: encodedKey), "SUPublicEDKey is not base64")
        XCTAssertEqual(key.count, 32)
    }
}

@MainActor
final class UpdateControllerTests: XCTestCase {
    func testSilentDiscoveryAdvertisesUpdateWithoutShowingAnAlert() throws {
        let controller = UpdateController()
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                 userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil), delegate: nil)
        // This fixture only uses version strings, which the public initializer supports.
        let item = try XCTUnwrap(SUAppcastItem(dictionary: [
            "sparkle:version": "99.0.0",
            "sparkle:shortVersionString": "99.0",
            "enclosure": ["url": "https://example.com/Quikanva.zip"],
        ]))

        controller.updater(updater, didFindValidUpdate: item)

        // No standard-user-driver callback occurs during a silent automatic download.
        XCTAssertEqual(controller.availableUpdateVersion, "99.0")

        controller.standardUserDriverDidReceiveUserAttention(forUpdate: item)
        XCTAssertNil(controller.availableUpdateVersion)

        controller.updater(updater, didFindValidUpdate: item)
        controller.standardUserDriverWillFinishUpdateSession()
        XCTAssertNil(controller.availableUpdateVersion)

        controller.updater(updater, didFindValidUpdate: item)
        controller.updaterDidNotFindUpdate(updater)
        XCTAssertNil(controller.availableUpdateVersion)
    }
}
