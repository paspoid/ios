import CryptoKit
import XCTest
@testable import PaspoIDWire

final class PaspoWireTests: XCTestCase {
    private let redirectURL = URL(string: "https://demo.paspo.id/paspo/callback")!

    // MARK: - Request

    func testAuthRequestRoundTripsThroughURL() throws {
        let key = P256.KeyAgreement.PrivateKey()
        let request = PaspoAuthRequest(
            nonce: "nonce-1",
            clientPublicKeyDER: key.publicKey.derRepresentation,
            bundleID: "paspo.id.demo",
            scope: .emails,
            redirectURL: redirectURL,
            state: "state-1",
            referralNonce: "referral-1"
        )

        let url = try XCTUnwrap(request.makeURL())
        XCTAssertEqual(url.scheme, "paspo")
        XCTAssertEqual(url.host, "sso")

        let parsed = try XCTUnwrap(PaspoAuthRequest.parse(url: url))
        XCTAssertEqual(parsed, request)
    }

    func testAuthRequestRejectsMissingParameters() {
        XCTAssertNil(PaspoAuthRequest.parse(url: URL(string: "paspo://sso?nonce=n")!))
        XCTAssertNil(PaspoAuthRequest.parse(url: URL(string: "paspo://web-auth?c=code")!))
        XCTAssertNil(PaspoAuthRequest.parse(url: URL(string: "https://paspo.id/sso?nonce=n")!))
    }

    func testAuthRequestRejectsUnknownScope() throws {
        let key = P256.KeyAgreement.PrivateKey()
        let request = PaspoAuthRequest(
            nonce: "n",
            clientPublicKeyDER: key.publicKey.derRepresentation,
            bundleID: "paspo.id.demo",
            scope: .phones,
            redirectURL: redirectURL,
            state: "s"
        )
        let url = try XCTUnwrap(request.makeURL())
        let broken = URL(string: url.absoluteString.replacingOccurrences(of: "scope=phones", with: "scope=retina"))!

        XCTAssertNil(PaspoAuthRequest.parse(url: broken))
    }

    // MARK: - Callback

    func testSuccessCallbackRoundTrip() throws {
        let clientKey = P256.KeyAgreement.PrivateKey()
        let envelope = try PaspoEncryptedEnvelope.seal(
            PaspoSSOResult.success(nonce: "auth-code"),
            recipientPublicKeyDER: clientKey.publicKey.derRepresentation
        )

        let url = try XCTUnwrap(try PaspoAuthCallback.success(state: "s1", envelope: envelope).makeURL(redirectURL: redirectURL))
        let callback = try XCTUnwrap(PaspoAuthCallback.parse(url: url))

        guard case let .success(state, parsedEnvelope) = callback else {
            return XCTFail("Expected success, got \(callback)")
        }
        XCTAssertEqual(state, "s1")

        let payload = try parsedEnvelope.open(PaspoSSOResult.self, privateKey: clientKey)
        XCTAssertEqual(payload, .success(nonce: "auth-code"))
    }

    func testCallbackPreservesExistingQueryOfRedirect() throws {
        let redirect = URL(string: "https://demo.paspo.id/callback?flow=signup")!
        let url = try XCTUnwrap(try PaspoAuthCallback.cancelled(state: "s2").makeURL(redirectURL: redirect))

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "flow" })?.value, "signup")
        XCTAssertEqual(PaspoAuthCallback.parse(url: url), .cancelled(state: "s2"))
    }

    func testFailureCallbackCarriesErrorCode() throws {
        let url = try XCTUnwrap(
            try PaspoAuthCallback.failure(state: "s3", errorCode: PaspoClientError.accessDenied.code)
                .makeURL(redirectURL: redirectURL)
        )
        XCTAssertEqual(PaspoAuthCallback.parse(url: url), .failure(state: "s3", errorCode: 120))
    }

    func testCorruptEnvelopeBecomesInvalidRequest() {
        let url = URL(string: "https://demo.paspo.id/paspo/callback?paspo_result=success&state=s4&d=not-base64url!!")!
        XCTAssertEqual(PaspoAuthCallback.parse(url: url), .failure(state: "s4", errorCode: PaspoClientError.invalidRequest.code))
    }

    func testUnrelatedURLIsNotACallback() {
        XCTAssertNil(PaspoAuthCallback.parse(url: URL(string: "https://demo.paspo.id/paspo/callback")!))
        XCTAssertNil(PaspoAuthCallback.parse(url: URL(string: "https://demo.paspo.id/?paspo_result=success")!))
    }

    // MARK: - Envelope

    func testEnvelopeJSONUsesBase64URLFields() throws {
        let envelope = PaspoEncryptedEnvelope(
            senderPublicKey: Data([0xFB, 0xFF]),
            iv: Data(repeating: 1, count: 12),
            ciphertext: Data(repeating: 2, count: 32)
        )
        let json = try XCTUnwrap(String(data: try JSONEncoder().encode(envelope), encoding: .utf8))

        XCTAssertTrue(json.contains("\"sender_public_key\":\"-_8\""))
        XCTAssertFalse(json.contains("="))
        XCTAssertEqual(try JSONDecoder().decode(PaspoEncryptedEnvelope.self, from: Data(json.utf8)), envelope)
    }

    func testEnvelopeOpenedWithWrongKeyFails() throws {
        let envelope = try PaspoEncryptedEnvelope.seal(
            PaspoSSOResult.success(nonce: "auth-code"),
            recipientPublicKeyDER: P256.KeyAgreement.PrivateKey().publicKey.derRepresentation
        )

        XCTAssertThrowsError(try envelope.open(PaspoSSOResult.self, privateKey: P256.KeyAgreement.PrivateKey()))
    }

    /// The payload discriminator must stay kotlinx-compatible: `type` + snake_case fields.
    func testSSOResultJSONMatchesAndroid() throws {
        let success = try JSONEncoder().encode(PaspoSSOResult.success(nonce: "n"))
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: success) as? [String: Any])
        XCTAssertEqual(fields["type"] as? String, "success")
        XCTAssertEqual(fields["nonce"] as? String, "n")

        let failure = try JSONDecoder().decode(PaspoSSOResult.self, from: Data(#"{"type":"failure","error_code":121}"#.utf8))
        XCTAssertEqual(failure, .failure(errorCode: 121))
    }

    func testClientErrorCodesMatchAndroid() {
        XCTAssertEqual(PaspoClientError.unknown.code, 100)
        XCTAssertEqual(PaspoClientError.invalidRequest.code, 101)
        XCTAssertEqual(PaspoClientError.cancelled.code, 103)
        XCTAssertEqual(PaspoClientError.packageVerificationFailed.code, 111)
        XCTAssertEqual(PaspoClientError.cryptoError.code, 141)
        XCTAssertEqual(PaspoClientError.from(code: 999), .unknown)
    }

    func testScopeKeysMatchAndroid() {
        XCTAssertEqual(PaspoScope.phones.key, "phones")
        XCTAssertEqual(PaspoScope.emails.key, "emails")
        XCTAssertEqual(PaspoScope.nationalID.key, "national_id")
        XCTAssertEqual(PaspoScope.paspoID.key, "paspo_id")
        XCTAssertEqual(PaspoScope(key: "paspo_id"), .paspoID)
        XCTAssertNil(PaspoScope(key: "unknown"))
    }
}
