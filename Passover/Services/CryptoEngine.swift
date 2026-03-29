import CryptoKit
import Foundation

/// Pure cryptographic operations — no Keychain or networking.
enum CryptoEngine {
    enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
    }

    static func computeSharedSecret(
        privateKey: P256.KeyAgreement.PrivateKey,
        peerPublicKeyBytes: Data
    ) throws -> SharedSecret {
        let peerPublicKey = try P256.KeyAgreement.PublicKey(derRepresentation: peerPublicKeyBytes)
        return try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
    }

    static func deriveSessionKey(sharedSecret: SharedSecret) -> SymmetricKey {
        sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(count: 32),
            sharedInfo: "passover-pairing".data(using: .utf8)!,
            outputByteCount: 32
        )
    }

    static func computeSasCode(localPubKey: Data, remotePubKey: Data) -> String {
        let sorted: Data
        if localPubKey.lexicographicallyPrecedes(remotePubKey) {
            sorted = localPubKey + remotePubKey
        } else {
            sorted = remotePubKey + localPubKey
        }

        let hash = SHA256.hash(data: sorted)
        let bytes = Array(hash)

        let num = (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])

        let code = num % 1_000_000
        return String(format: "%06d", code)
    }

    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}
