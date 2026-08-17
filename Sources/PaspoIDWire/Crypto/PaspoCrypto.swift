import CryptoKit
import Foundation

/// Cryptographic primitives of the SSO envelope.
///
/// Every parameter here mirrors the Android SDK byte for byte:
/// - ECDH on P-256 (`secp256r1`), public keys exchanged as X.509 `SubjectPublicKeyInfo` DER,
///   which is what Java's `PublicKey.getEncoded()` produces.
/// - HKDF-SHA256 with an all-zero 32-byte salt and a context string, 32 bytes of output.
///   Android hand-rolls exactly one extract + one expand block, which is HKDF for a single block.
/// - AES-256-GCM with a random 12-byte IV and a 128-bit tag. On the wire `ciphertext`
///   carries the tag appended at the end, as the JCE does.
public enum PaspoCrypto {
    public static let aesKeyByteCount = 32
    public static let gcmIVByteCount = 12
    public static let gcmTagByteCount = 16

    // MARK: - Key agreement

    /// Derives the AES key shared with `peerPublicKeyDER` for the given KDF `info` context.
    public static func deriveSharedKey(
        privateKey: P256.KeyAgreement.PrivateKey,
        peerPublicKeyDER: Data,
        info: String
    ) throws -> SymmetricKey {
        let peerKey: P256.KeyAgreement.PublicKey
        do {
            peerKey = try P256.KeyAgreement.PublicKey(derRepresentation: peerPublicKeyDER)
        } catch {
            throw PaspoCryptoError.invalidPeerPublicKey
        }

        let sharedSecret: SharedSecret
        do {
            sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        } catch {
            throw PaspoCryptoError.keyAgreementFailed
        }

        return deriveAESKey(sharedSecret: sharedSecret.withUnsafeBytes { Data($0) }, info: info)
    }

    /// HKDF-SHA256 over a raw shared secret. Exposed for cross-platform test vectors.
    public static func deriveAESKey(
        sharedSecret: Data,
        info: String,
        salt: Data = Data(repeating: 0, count: 32)
    ) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: sharedSecret),
            salt: salt,
            info: Data(info.utf8),
            outputByteCount: aesKeyByteCount
        )
    }

    // MARK: - AEAD

    /// Encrypts `plaintext`, returning the IV and the ciphertext with the GCM tag appended.
    public static func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> (iv: Data, ciphertext: Data) {
        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: key)
            // `Data(_:)` re-bases the buffers: CryptoKit hands back slices whose `startIndex`
            // is not 0, and concatenation would inherit that, breaking `data[0]` for callers.
            return (Data(sealedBox.nonce), Data(sealedBox.ciphertext) + Data(sealedBox.tag))
        } catch {
            throw PaspoCryptoError.encryptionFailed
        }
    }

    /// Decrypts a `ciphertext` that carries the GCM tag in its trailing 16 bytes.
    public static func decrypt(iv: Data, ciphertext: Data, key: SymmetricKey) throws -> Data {
        guard iv.count == gcmIVByteCount, ciphertext.count > gcmTagByteCount else {
            throw PaspoCryptoError.malformedCiphertext
        }
        let body = Data(ciphertext)
        let tagIndex = body.count - gcmTagByteCount
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: iv),
                ciphertext: body.prefix(tagIndex),
                tag: body.suffix(gcmTagByteCount)
            )
            return Data(try AES.GCM.open(sealedBox, using: key))
        } catch {
            throw PaspoCryptoError.decryptionFailed
        }
    }
}

/// Low-level cryptographic failures. All of them surface to client code as
/// ``PaspoClientError/cryptoError``.
public enum PaspoCryptoError: Error, Sendable, Equatable {
    case invalidPeerPublicKey
    case keyAgreementFailed
    case encryptionFailed
    case decryptionFailed
    case malformedCiphertext
}
