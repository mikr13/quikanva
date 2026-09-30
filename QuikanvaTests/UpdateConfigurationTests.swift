import XCTest

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
