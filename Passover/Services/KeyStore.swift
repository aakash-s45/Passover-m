import Foundation
import CryptoKit
import Security
import OSLog


final class KeyStore {
    private static let keyService = "com.local.passover"
    private static let kKeyAgreement = "passover_key_agreement"
    private static let kKeySigning = "passover_key_signing"
    private static let kGroupKey = "passover_group_key"
    
    enum KeychainError: Error, LocalizedError{
        case keyNotFound
        case keyGenerationFailed
        case keySaveFailed(OSStatus)
        case keyLoadFailed(OSStatus)
        case keyDataMismatch
        case encryptionFailed
        case decryptionFailed
        
        var errorDescription: String? {
            switch self {
            case .keyGenerationFailed: return "Failed to generate a new symmetric key."
            case .keySaveFailed(let status): return "Failed to save key to Keychain. OSStatus: \(status)"
            case .keyLoadFailed(let status): return "Failed to load key from Keychain. OSStatus: \(status)"
            case .keyDataMismatch: return "Keychain returned data in an unexpected format."
            case .encryptionFailed: return "Data encryption failed."
            case .decryptionFailed: return "Data decryption failed. The data may be corrupt or the key incorrect."
            case .keyNotFound: return "Key not found"
            }
        }
    }
    
    // ── P-256 Key Agreement Pair ──────────────────────────────────────────
    
    public static func getOrCreateKeyAgreementPair() -> P256.KeyAgreement.PrivateKey {
        if let stored = loadPrivateKeyData(account: kKeyAgreement) {
            do {
                return try P256.KeyAgreement.PrivateKey(rawRepresentation: stored)
            } catch {
                Logger.connection.error("Failed to load key agreement pair, regenerating: \(error)")
            }
        }
        
        let newKey = P256.KeyAgreement.PrivateKey()
        savePrivateKeyData(newKey.rawRepresentation, account: kKeyAgreement)
        Logger.connection.info("Generated new P-256 key agreement pair")
        return newKey
    }
    
    public static func getPublicKeyAgreement() -> Data {
        let privateKey = getOrCreateKeyAgreementPair()
        return privateKey.publicKey.derRepresentation
    }
    
    // ── P-256 Signing Pair ────────────────────────────────────────────────
    
    public static func getOrCreateSigningPair() -> P256.Signing.PrivateKey {
        if let stored = loadPrivateKeyData(account: kKeySigning) {
            do {
                return try P256.Signing.PrivateKey(rawRepresentation: stored)
            } catch {
                Logger.connection.error("Failed to load signing pair, regenerating: \(error)")
            }
        }
        
        let newKey = P256.Signing.PrivateKey()
        savePrivateKeyData(newKey.rawRepresentation, account: kKeySigning)
        Logger.connection.info("Generated new P-256 signing pair")
        return newKey
    }
    
    public static func getPublicKeySignature() -> Data {
        let privateKey = getOrCreateSigningPair()
        return privateKey.publicKey.derRepresentation
    }
    
    // ── Shared Secret / Session Key ───────────────────────────────────────
    
    public static func computeSharedSecret(peerPublicKeyBytes: Data) throws -> SharedSecret {
        let privateKey = getOrCreateKeyAgreementPair()
        let peerPublicKey = try P256.KeyAgreement.PublicKey(derRepresentation: peerPublicKeyBytes)
        return try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
    }
    
    public static func deriveSessionKey(sharedSecret: SharedSecret) -> SymmetricKey {
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(count: 32),
            sharedInfo: "passover-pairing".data(using: .utf8)!,
            outputByteCount: 32
        )
    }
    
    // ── GroupKey Management ────────────────────────────────────────────────
    
    public static func generateGroupKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    public static func getOrCreateGroupKey() -> SymmetricKey {
        if let stored = loadPrivateKeyData(account: kGroupKey) {
            return SymmetricKey(data: stored)
        }
        let newKey = generateGroupKey()
        saveGroupKey(newKey)
        return newKey
    }
    
    public static func saveGroupKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        savePrivateKeyData(keyData, account: kGroupKey)
        Logger.connection.info("Saved group key")
    }
    
    public static func hasGroupKey() -> Bool {
        return loadPrivateKeyData(account: kGroupKey) != nil
    }
    
    public static func clearGroupKey() {
        deleteKeychainItem(account: kGroupKey)
    }
    
    // ── SAS Code Computation ──────────────────────────────────────────────
    
    public static func computeSasCode(localPubKey: Data, remotePubKey: Data) -> String {
        let sorted: Data
        if localPubKey.lexicographicallyPrecedes(remotePubKey) {
            sorted = localPubKey + remotePubKey
        } else {
            sorted = remotePubKey + localPubKey
        }
        
        let hash = SHA256.hash(data: sorted)
        let bytes = Array(hash)
        
        let num = (UInt32(bytes[0]) << 24) |
                  (UInt32(bytes[1]) << 16) |
                  (UInt32(bytes[2]) << 8) |
                  UInt32(bytes[3])
        
        let code = num % 1_000_000
        return String(format: "%06d", code)
    }
    
    // ── AES-GCM Encrypt / Decrypt ─────────────────────────────────────────
    
    public static func encrypt(_ data: Data, using key:SymmetricKey) throws -> Data{
        do{
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else{
                throw KeychainError.encryptionFailed
            }
            return combined
        } catch {
            throw KeychainError.encryptionFailed
        }
    }
    
    public static func decrypt(_ data: Data, using key:SymmetricKey) throws -> Data{
        do{
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        }catch{
            throw KeychainError.decryptionFailed
        }
    }
    
    // ── Private Keychain Helpers ──────────────────────────────────────────
    
    private static func savePrivateKeyData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.connection.error("Failed to save key data for \(account): OSStatus \(status)")
        }
    }
    
    private static func loadPrivateKeyData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }
    
    private static func deleteKeychainItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
