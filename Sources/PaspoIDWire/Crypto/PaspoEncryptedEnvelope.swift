import CryptoKit
import Foundation

/// Encrypted container carrying the SSO response from Paspo ID back to the client.
///
/// The cryptographic construction is identical to Android's `EncryptedEnvelope`; only the
/// serialization differs: on iOS the envelope travels inside a URL, so the byte fields are
/// base64url strings rather than kotlinx byte arrays.
///
/// ```json
/// { "v": 1, "sender_public_key": "<base64url>", "iv": "<base64url>", "ciphertext": "<base64url>" }
/// ```
public struct PaspoEncryptedEnvelope: Codable, Sendable, Equatable {
    /// Contract version, see ``PaspoSSOConstants/contractVersion``.
    public let version: Int
    /// Ephemeral X.509 P-256 public key of whoever sealed this envelope.
    public let senderPublicKey: Data
    /// AES-GCM initialization vector, 12 bytes.
    public let iv: Data
    /// AES-GCM ciphertext with the 16-byte tag appended.
    public let ciphertext: Data

    public init(version: Int = PaspoSSOConstants.contractVersion, senderPublicKey: Data, iv: Data, ciphertext: Data) {
        self.version = version
        self.senderPublicKey = senderPublicKey
        self.iv = iv
        self.ciphertext = ciphertext
    }

    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case senderPublicKey = "sender_public_key"
        case iv
        case ciphertext
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? PaspoSSOConstants.contractVersion
        senderPublicKey = try container.decodeBase64URL(forKey: .senderPublicKey)
        iv = try container.decodeBase64URL(forKey: .iv)
        ciphertext = try container.decodeBase64URL(forKey: .ciphertext)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(Base64URL.encode(senderPublicKey), forKey: .senderPublicKey)
        try container.encode(Base64URL.encode(iv), forKey: .iv)
        try container.encode(Base64URL.encode(ciphertext), forKey: .ciphertext)
    }
}

// MARK: - Sealing / opening

public extension PaspoEncryptedEnvelope {
    /// Seals `payload` for the holder of `recipientPublicKeyDER` using a freshly generated
    /// ephemeral key pair. Used by the Paspo ID app to answer an authentication request.
    static func seal(
        _ payload: some Encodable,
        recipientPublicKeyDER: Data,
        info: String = PaspoKDFContext.authResponse
    ) throws -> PaspoEncryptedEnvelope {
        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        let aesKey = try PaspoCrypto.deriveSharedKey(
            privateKey: ephemeralKey,
            peerPublicKeyDER: recipientPublicKeyDER,
            info: info
        )
        let plaintext = try JSONEncoder().encode(payload)
        let sealed = try PaspoCrypto.encrypt(plaintext, key: aesKey)
        return PaspoEncryptedEnvelope(
            senderPublicKey: ephemeralKey.publicKey.derRepresentation,
            iv: sealed.iv,
            ciphertext: sealed.ciphertext
        )
    }

    /// Opens the envelope with the recipient's ephemeral private key and decodes its payload.
    func open<T: Decodable>(
        _ type: T.Type,
        privateKey: P256.KeyAgreement.PrivateKey,
        info: String = PaspoKDFContext.authResponse
    ) throws -> T {
        let aesKey = try PaspoCrypto.deriveSharedKey(
            privateKey: privateKey,
            peerPublicKeyDER: senderPublicKey,
            info: info
        )
        let plaintext = try PaspoCrypto.decrypt(iv: iv, ciphertext: ciphertext, key: aesKey)
        do {
            return try JSONDecoder().decode(type, from: plaintext)
        } catch {
            throw PaspoCryptoError.malformedCiphertext
        }
    }

    /// Serializes the envelope to the base64url form carried in the `d` callback parameter.
    func encodedForTransport() throws -> String {
        Base64URL.encode(try JSONEncoder().encode(self))
    }

    /// Parses the `d` callback parameter.
    static func decodeFromTransport(_ value: String) throws -> PaspoEncryptedEnvelope {
        guard let json = Base64URL.decode(value) else { throw PaspoCryptoError.malformedCiphertext }
        do {
            return try JSONDecoder().decode(PaspoEncryptedEnvelope.self, from: json)
        } catch {
            throw PaspoCryptoError.malformedCiphertext
        }
    }
}

// MARK: - Helpers

private extension KeyedDecodingContainer {
    func decodeBase64URL(forKey key: Key) throws -> Data {
        let encoded = try decode(String.self, forKey: key)
        guard let data = Base64URL.decode(encoded) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not base64url")
        }
        return data
    }
}
