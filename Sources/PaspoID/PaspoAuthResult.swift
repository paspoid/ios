import Foundation
import PaspoIDWire

/// Outcome of ``Paspo/authenticate(scope:nonce:)``.
///
/// The single channel for every result of the SSO flow: `authenticate` never throws for
/// flow-level outcomes, it always returns one of these cases.
public enum PaspoAuthResult: Sendable, Equatable {
    /// The user confirmed authentication in Paspo ID.
    ///
    /// - Parameter authCode: One-time authorization code. Pass it to your backend, which
    ///   exchanges it for the user data via the Paspo server API. The code itself carries
    ///   no personal data.
    case success(authCode: String)

    /// The user dismissed the Paspo ID consent screen, or returned without completing it.
    /// Usually requires no error UI.
    case cancelled

    /// The Paspo ID app is not installed. The SDK has already opened its App Store page
    /// when ``PaspoConfiguration/appStoreURL`` is set; call `authenticate` again once the
    /// user has installed it.
    case notInstalled

    /// The flow failed.
    ///
    /// - Parameters:
    ///   - error: Failure reason.
    ///   - message: Optional diagnostic detail. Not localized — log it, do not show it.
    case failure(error: PaspoClientError, message: String?)
}
