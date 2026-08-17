import CryptoKit
import XCTest
@testable import PaspoIDWire

final class PaspoCryptoTests: XCTestCase {
    /// Cross-platform vector: HKDF-SHA256 with an all-zero 32-byte salt, as hand-rolled by the
    /// Android SDK (`prk = HMAC(salt, ikm)`, `okm = HMAC(prk, info || 0x01)`).
    func testKeyDerivationMatchesAndroidConstruction() throws {
        let sharedSecret = Data((0 ..< 32).map { UInt8($0) })
        let info = PaspoKDFContext.authResponse

        let derived = PaspoCrypto.deriveAESKey(sharedSecret: sharedSecret, info: info)

        let salt = Data(repeating: 0, count: 32)
        let prk = HMAC<SHA256>.authenticationCode(for: sharedSecret, using: SymmetricKey(data: salt))
        let expected = HMAC<SHA256>.authenticationCode(
            for: Data(info.utf8) + Data([0x01]),
            using: SymmetricKey(data: Data(prk))
        )

        XCTAssertEqual(derived.withUnsafeBytes { Data($0) }, Data(expected))
    }

    func testKDFContextStringsAreStable() {
        XCTAssertEqual(PaspoKDFContext.authRequest, "paspo_id_auth_req_v1")
        XCTAssertEqual(PaspoKDFContext.authResponse, "paspo_id_auth_res_v1")
    }

    func testEncryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("paspo".utf8)

        let sealed = try PaspoCrypto.encrypt(plaintext, key: key)

        XCTAssertEqual(sealed.iv.count, PaspoCrypto.gcmIVByteCount)
        XCTAssertEqual(sealed.ciphertext.count, plaintext.count + PaspoCrypto.gcmTagByteCount)
        XCTAssertEqual(try PaspoCrypto.decrypt(iv: sealed.iv, ciphertext: sealed.ciphertext, key: key), plaintext)
    }

    func testDecryptRejectsTamperedCiphertext() throws {
        let key = SymmetricKey(size: .bits256)
        var sealed = try PaspoCrypto.encrypt(Data("paspo".utf8), key: key)
        sealed.ciphertext[0] ^= 0xFF

        XCTAssertThrowsError(try PaspoCrypto.decrypt(iv: sealed.iv, ciphertext: sealed.ciphertext, key: key))
    }

    func testDecryptRejectsShortIV() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertThrowsError(
            try PaspoCrypto.decrypt(iv: Data(repeating: 0, count: 8), ciphertext: Data(repeating: 1, count: 32), key: key)
        )
    }

    /// Both sides agree on the same key even though each holds only its own private key —
    /// the property the whole envelope rests on.
    func testSharedKeyAgreementIsSymmetric() throws {
        let client = P256.KeyAgreement.PrivateKey()
        let host = P256.KeyAgreement.PrivateKey()

        let clientSide = try PaspoCrypto.deriveSharedKey(
            privateKey: client,
            peerPublicKeyDER: host.publicKey.derRepresentation,
            info: PaspoKDFContext.authResponse
        )
        let hostSide = try PaspoCrypto.deriveSharedKey(
            privateKey: host,
            peerPublicKeyDER: client.publicKey.derRepresentation,
            info: PaspoKDFContext.authResponse
        )

        XCTAssertEqual(clientSide, hostSide)
    }

    func testDeriveSharedKeyRejectsGarbagePeerKey() {
        XCTAssertThrowsError(
            try PaspoCrypto.deriveSharedKey(
                privateKey: P256.KeyAgreement.PrivateKey(),
                peerPublicKeyDER: Data([0x01, 0x02, 0x03]),
                info: PaspoKDFContext.authResponse
            )
        ) { error in
            XCTAssertEqual(error as? PaspoCryptoError, .invalidPeerPublicKey)
        }
    }

    func testBase64URLRoundTripsWithoutPadding() {
        for length in 1 ... 64 {
            let data = Data((0 ..< length).map { _ in UInt8.random(in: .min ... .max) })
            let encoded = Base64URL.encode(data)
            XCTAssertFalse(encoded.contains("="))
            XCTAssertFalse(encoded.contains("+"))
            XCTAssertFalse(encoded.contains("/"))
            XCTAssertEqual(Base64URL.decode(encoded), data)
        }
    }
}
