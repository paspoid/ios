import Foundation

/// Set of profile data the client application requests from the user.
///
/// The user sees the requested scope on the Paspo ID consent screen and can decline it.
public enum PaspoScope: String, Sendable, CaseIterable, Codable {
    /// Phone numbers of the profile.
    case phones
    /// E-mail addresses of the profile.
    case emails
    /// National identity document number.
    case nationalID = "national_id"
    /// Permanent user identifier in Paspo ID.
    case paspoID = "paspo_id"

    /// Wire value of the scope, as sent to the Paspo ID app.
    public var key: String { rawValue }

    /// Resolves a scope from its wire ``key``, or `nil` if unknown.
    public init?(key: String) {
        self.init(rawValue: key)
    }
}
