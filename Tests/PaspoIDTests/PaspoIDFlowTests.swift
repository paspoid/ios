import CryptoKit
import XCTest
@testable import PaspoID
@testable import PaspoIDWire

@MainActor
final class PaspoIDFlowTests: XCTestCase {
    private let redirectURL = URL(string: "https://demo.paspo.id/paspo/callback")!
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id0000000000")!

    private func makeSDK(
        isPaspoInstalled: Bool = true,
        fallbackRedirectURL: URL? = nil,
        defaults: UserDefaults
    ) -> (Paspo, FakeURLOpener) {
        let opener = FakeURLOpener(canOpenAnything: isPaspoInstalled)
        let configuration = PaspoConfiguration(
            redirectURL: redirectURL,
            fallbackRedirectURL: fallbackRedirectURL,
            bundleID: "paspo.id.demo",
            appStoreURL: appStoreURL,
            callbackTimeout: 0,
            cancellationGracePeriod: 0
        )
        let sdk = Paspo(
            configuration: configuration,
            urlOpener: opener,
            referralStore: PaspoReferralStore(defaults: defaults)
        )
        return (sdk, opener)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "paspo.tests.\(UUID().uuidString)"))
        addTeardownBlock { suite.removePersistentDomain(forName: suite.description) }
        return suite
    }

    /// Starts a flow and returns the request Paspo ID would have received.
    private func startFlow(
        _ sdk: Paspo,
        _ opener: FakeURLOpener,
        scope: PaspoScope = .phones,
        nonce: String = "backend-nonce"
    ) async throws -> (task: Task<PaspoAuthResult, Never>, request: PaspoAuthRequest) {
        let task = Task { await sdk.authenticate(scope: scope, nonce: nonce) }
        let openedURL = try await opener.waitForOpenedURL()
        return (task, try XCTUnwrap(PaspoAuthRequest.parse(url: openedURL)))
    }

    // MARK: - Request

    func testAuthenticateOpensPaspoWithTheConfiguredRedirect() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener, scope: .emails, nonce: "n-42")

        XCTAssertEqual(request.nonce, "n-42")
        XCTAssertEqual(request.scope, .emails)
        XCTAssertEqual(request.bundleID, "paspo.id.demo")
        XCTAssertEqual(request.redirectURL, redirectURL)
        XCTAssertFalse(request.state.isEmpty)
        XCTAssertFalse(request.clientPublicKeyDER.isEmpty)

        sdk.cleanup()
        _ = await task.value
    }

    func testEmptyNonceIsRejectedWithoutLeavingTheApp() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())

        let result = await sdk.authenticate(scope: .phones, nonce: "")

        XCTAssertEqual(result, .failure(error: .invalidRequest, message: "Empty nonce"))
        XCTAssertTrue(opener.openedURLs.isEmpty)
    }

    // MARK: - Not installed

    func testMissingPaspoOpensAppStoreAndStoresReferral() async throws {
        let defaults = try makeDefaults()
        let (sdk, opener) = makeSDK(isPaspoInstalled: false, defaults: defaults)

        let result = await sdk.authenticate(scope: .phones, nonce: "n-1")

        XCTAssertEqual(result, .notInstalled)
        XCTAssertEqual(opener.openedURLs, [appStoreURL])
        XCTAssertEqual(PaspoReferralStore(defaults: defaults).load(), "n-1")
    }

    func testStoredReferralIsSentWithTheNextAttempt() async throws {
        let defaults = try makeDefaults()
        PaspoReferralStore(defaults: defaults).save(nonce: "install-nonce")
        let (sdk, opener) = makeSDK(defaults: defaults)

        let (task, request) = try await startFlow(sdk, opener)

        XCTAssertEqual(request.referralNonce, "install-nonce")
        sdk.cleanup()
        _ = await task.value
    }

    // MARK: - Callback

    func testSuccessCallbackResolvesWithAuthCode() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let envelope = try PaspoEncryptedEnvelope.seal(
            PaspoSSOResult.success(nonce: "auth-code-7"),
            recipientPublicKeyDER: request.clientPublicKeyDER
        )
        let callbackURL = try XCTUnwrap(
            try PaspoAuthCallback.success(state: request.state, envelope: envelope).makeURL(redirectURL: redirectURL)
        )

        XCTAssertTrue(sdk.handle(url: callbackURL))
        let result = await task.value
        XCTAssertEqual(result, .success(authCode: "auth-code-7"))
    }

    func testCallbackOnTheFallbackSchemeIsAccepted() async throws {
        let fallback = URL(string: "paspo-demo://paspo-callback")!
        let (sdk, opener) = makeSDK(fallbackRedirectURL: fallback, defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let envelope = try PaspoEncryptedEnvelope.seal(
            PaspoSSOResult.success(nonce: "code"),
            recipientPublicKeyDER: request.clientPublicKeyDER
        )
        let callbackURL = try XCTUnwrap(
            try PaspoAuthCallback.success(state: request.state, envelope: envelope).makeURL(redirectURL: fallback)
        )

        XCTAssertTrue(sdk.handle(url: callbackURL))
        let resultTask = await task.value
        XCTAssertEqual(resultTask, .success(authCode: "code"))
    }

    func testCallbackWithForeignStateIsIgnored() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let envelope = try PaspoEncryptedEnvelope.seal(
            PaspoSSOResult.success(nonce: "attacker-code"),
            recipientPublicKeyDER: request.clientPublicKeyDER
        )
        let forged = try XCTUnwrap(
            try PaspoAuthCallback.success(state: "someone-elses-state", envelope: envelope).makeURL(redirectURL: redirectURL)
        )

        XCTAssertTrue(sdk.handle(url: forged), "Consumed, but must not resolve the live flow")

        // The flow is still pending: only an explicit cleanup ends it.
        sdk.cleanup()
        let resultTask = await task.value
        XCTAssertEqual(resultTask, .cancelled)
    }

    func testEnvelopeEncryptedForAnotherKeyFailsAsCryptoError() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let envelope = try PaspoEncryptedEnvelope.seal(
            PaspoSSOResult.success(nonce: "code"),
            recipientPublicKeyDER: P256.KeyAgreement.PrivateKey().publicKey.derRepresentation
        )
        let callbackURL = try XCTUnwrap(
            try PaspoAuthCallback.success(state: request.state, envelope: envelope).makeURL(redirectURL: redirectURL)
        )
        sdk.handle(url: callbackURL)

        guard case let .failure(error, _) = await task.value else { return XCTFail("Expected a failure") }
        XCTAssertEqual(error, .cryptoError)
    }

    func testErrorCallbackResolvesWithMatchingError() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let callbackURL = try XCTUnwrap(
            try PaspoAuthCallback.failure(state: request.state, errorCode: PaspoClientError.identityNotVerified.code)
                .makeURL(redirectURL: redirectURL)
        )
        sdk.handle(url: callbackURL)

        let resultTask = await task.value
        XCTAssertEqual(resultTask, .failure(error: .identityNotVerified, message: nil))
    }

    /// Paspo reports cancellation as error code 103; it must surface as `.cancelled`, never
    /// as a failure the integrator has to special-case.
    func testCancelledErrorCodeBecomesCancelled() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let callbackURL = try XCTUnwrap(
            try PaspoAuthCallback.failure(state: request.state, errorCode: PaspoClientError.cancelled.code)
                .makeURL(redirectURL: redirectURL)
        )
        sdk.handle(url: callbackURL)

        let resultTask = await task.value
        XCTAssertEqual(resultTask, .cancelled)
    }

    func testCancelledCallbackResolvesAsCancelled() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (task, request) = try await startFlow(sdk, opener)

        let callbackURL = try XCTUnwrap(
            try PaspoAuthCallback.cancelled(state: request.state).makeURL(redirectURL: redirectURL)
        )
        sdk.handle(url: callbackURL)

        let resultTask = await task.value
        XCTAssertEqual(resultTask, .cancelled)
    }

    func testUnrelatedURLIsNotConsumed() async throws {
        let (sdk, _) = makeSDK(defaults: try makeDefaults())

        XCTAssertFalse(sdk.handle(url: URL(string: "https://example.com/callback?paspo_result=success&state=x")!))
        XCTAssertFalse(sdk.handle(url: URL(string: "https://demo.paspo.id/other?paspo_result=cancelled&state=x")!))
    }

    func testStartingANewFlowCancelsThePreviousOne() async throws {
        let (sdk, opener) = makeSDK(defaults: try makeDefaults())
        let (first, _) = try await startFlow(sdk, opener)

        let (second, _) = try await startFlow(sdk, opener, nonce: "second")

        let resultFirst = await first.value
        XCTAssertEqual(resultFirst, .cancelled)
        sdk.cleanup()
        _ = await second.value
    }

    func testFailureToOpenPaspoIsReportedAsServiceUnavailable() async throws {
        let opener = FakeURLOpener(canOpenAnything: true)
        opener.openSucceeds = false
        let sdk = Paspo(
            configuration: PaspoConfiguration(redirectURL: redirectURL, bundleID: "paspo.id.demo"),
            urlOpener: opener,
            referralStore: PaspoReferralStore(defaults: try makeDefaults())
        )

        let result = await sdk.authenticate(scope: .phones, nonce: "n")

        guard case let .failure(error, _) = result else { return XCTFail("Expected a failure") }
        XCTAssertEqual(error, .serviceUnavailable)
    }
}

// MARK: - Test doubles

@MainActor
private final class FakeURLOpener: PaspoURLOpening {
    private(set) var openedURLs: [URL] = []
    var canOpenAnything: Bool
    var openSucceeds = true

    private var waiters: [CheckedContinuation<URL, Never>] = []
    private var consumed = 0

    init(canOpenAnything: Bool) {
        self.canOpenAnything = canOpenAnything
    }

    func canOpen(_ url: URL) -> Bool {
        canOpenAnything
    }

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        if waiters.isEmpty == false {
            consumed += 1
            waiters.removeFirst().resume(returning: url)
        }
        return openSucceeds
    }

    /// Waits for the next `open` call that no earlier `waitForOpenedURL` has already taken.
    func waitForOpenedURL() async throws -> URL {
        if openedURLs.count > consumed {
            defer { consumed += 1 }
            return openedURLs[consumed]
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
