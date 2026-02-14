import Foundation
import CryptoKit
import Security
import OSLog


final class KeyStore {
    private static let keyService = "com.local.passover"
    
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
    
    
    public static func getNewKey() -> SymmetricKey{
        return SymmetricKey(size: .bits256)
    }
    
    public static func saveKey(key:SymmetricKey, for deviceId: String) throws {
        let keyData = key.withUnsafeBytes{ Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: deviceId,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.keySaveFailed(status)
        }
    }
    
    public static func getKey(deviceID: String)throws -> SymmetricKey{
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyService,
            kSecAttrAccount as String: deviceID,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound{
            throw KeychainError.keyNotFound
        }
        
        guard status == errSecSuccess else{
            throw KeychainError.keyLoadFailed(status)
        }
        
        guard let keyData = result as? Data else{
            throw KeychainError.keyDataMismatch
        }
        
        return SymmetricKey(data: keyData)
    }
    
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
}
