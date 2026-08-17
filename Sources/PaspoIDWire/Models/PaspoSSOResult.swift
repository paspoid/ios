import Foundation

/// Decrypted payload of the SSO response.
///
/// Wire-compatible with the Android SDK's `PaspoSsoResult`: kotlinx.serialization writes the
/// sealed-interface discriminator as `"type"`.
///
/// > Internal API. Client code receives `PaspoAuthResult` instead.
public enum PaspoSSOResult: Codable, Sendable, Equatable {
    /// The user confirmed authentication; `nonce` is the one-time authorization code.
    case success(nonce: String)
    /// The flow failed inside Paspo ID.
    case failure(errorCode: Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case nonce
        case errorCode = "error_code"
    }

    private enum Discriminator: String, Codable {
        case success
        case failure
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Discriminator.self, forKey: .type) {
        case .success:
            self = .success(nonce: try container.decode(String.self, forKey: .nonce))
        case .failure:
            self = .failure(errorCode: try container.decode(Int.self, forKey: .errorCode))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .success(nonce):
            try container.encode(Discriminator.success, forKey: .type)
            try container.encode(nonce, forKey: .nonce)
        case let .failure(errorCode):
            try container.encode(Discriminator.failure, forKey: .type)
            try container.encode(errorCode, forKey: .errorCode)
        }
    }
}
