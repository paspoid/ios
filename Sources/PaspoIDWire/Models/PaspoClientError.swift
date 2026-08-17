import Foundation

/// Failure reasons of the SSO flow, shared between the Paspo ID app and the client SDK.
///
/// Delivered to client code inside `PaspoAuthResult.failure`. Codes are identical to the
/// Android SDK, so the same error tables apply on both platforms.
public enum PaspoClientError: Int, Error, Sendable, CaseIterable {
    // General
    /// Unknown error.
    case unknown = 100
    /// Malformed request or corrupted data.
    case invalidRequest = 101
    /// Paspo ID is temporarily unavailable.
    case serviceUnavailable = 102
    /// The user cancelled the operation.
    case cancelled = 103

    // Session / integration
    /// The session expired; restart with a new nonce.
    case sessionExpired = 110
    /// The application failed Paspo's identity verification.
    /// Ensure the bundle identifier is registered during onboarding.
    case packageVerificationFailed = 111

    // Access
    /// The user denied access.
    case accessDenied = 120
    /// The user's identity is not verified in Paspo ID.
    case identityNotVerified = 121
    /// Too many attempts.
    case attemptsExceeded = 122
    /// Not available for this user.
    case actionNotAllowed = 123

    // Method
    /// The confirmation method is temporarily unavailable.
    case authMethodUnavailable = 130
    /// The confirmation method is not supported.
    case unsupportedAuthMethod = 131

    // Client-side
    /// Paspo ID is not installed.
    case paspoNotInstalled = 140
    /// Encryption or decryption error; restart the flow.
    case cryptoError = 141

    /// Numeric wire value of the error.
    public var code: Int { rawValue }

    /// Resolves an error from its wire ``code``, falling back to ``unknown``.
    public static func from(code: Int) -> PaspoClientError {
        PaspoClientError(rawValue: code) ?? .unknown
    }
}
