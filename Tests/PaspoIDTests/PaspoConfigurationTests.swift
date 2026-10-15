import XCTest
@testable import PaspoID

final class PaspoConfigurationTests: XCTestCase {
    private let redirectURL = URL(string: "https://your.app/paspo/callback")!

    func testLandingURLIsBuiltFromRegionAndServiceID() {
        let configuration = PaspoConfiguration(redirectURL: redirectURL, serviceID: "S6eFaRtr", region: "RU")
        XCTAssertEqual(configuration.landingURL?.absoluteString, "https://ru.paspo.id/mob/s/S6eFaRtr?flow=phone")
    }

    func testNoLandingWithoutServiceID() {
        XCTAssertNil(PaspoConfiguration(redirectURL: redirectURL).landingURL)
        XCTAssertNil(PaspoConfiguration(redirectURL: redirectURL, serviceID: "").landingURL)
    }

    func testFileFromTheAdminPanelConfiguresEverything() throws {
        let url = try writePlist([
            "SERVICE_ID": "S6eFaRtr",
            "REGION": "kz",
            "REDIRECT_URL": "https://your.app/paspo/callback",
            "FALLBACK_REDIRECT_URL": "yourapp://paspo-callback",
            "BUNDLE_ID": "your.app",
        ])

        let configuration = try PaspoConfiguration(contentsOf: url)

        XCTAssertEqual(configuration.serviceID, "S6eFaRtr")
        XCTAssertEqual(configuration.region, .kz)
        XCTAssertEqual(configuration.redirectURL, redirectURL)
        XCTAssertEqual(configuration.fallbackRedirectURL, URL(string: "yourapp://paspo-callback"))
        XCTAssertEqual(configuration.bundleID, "your.app")
        XCTAssertEqual(configuration.appClipURL, PaspoConfiguration.paspoAppClipURL)
    }

    func testFileWithoutARequiredKeyNamesIt() throws {
        let url = try writePlist(["SERVICE_ID": "S6eFaRtr", "REDIRECT_URL": "https://your.app/paspo/callback"])
        XCTAssertThrowsError(try PaspoConfiguration(contentsOf: url)) { error in
            XCTAssertEqual(error as? PaspoConfiguration.FileError, .missingKey("REGION"))
        }
    }

    func testMissingFileIsReported() {
        XCTAssertThrowsError(try PaspoConfiguration(bundle: Bundle(for: Self.self))) { error in
            XCTAssertEqual(error as? PaspoConfiguration.FileError, .notFound(PaspoConfiguration.fileName))
        }
    }

    private func writePlist(_ values: [String: String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).plist")
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
