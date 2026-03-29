import CryptoKit
import Foundation

/// Translates between raw wire bytes and `Message` values (optional AES-GCM with group key).
enum MessageCodec {
    enum WireMessage {
        case pairing(Message)
        case secure(Message)
    }

    /// Decrypt trusted traffic with the group key, or parse plain pairing protobufs.
    static func decode(data: Data, groupKey: SymmetricKey?) -> WireMessage? {
        if let key = groupKey {
            if let decrypted = try? CryptoEngine.decrypt(data, using: key),
               let message = try? Message(serializedBytes: decrypted) {
                return .secure(message)
            }
        }

        guard let message = try? Message(serializedBytes: data),
              isPairingMessage(message) else {
            return nil
        }
        return .pairing(message)
    }

    /// Serialize plain protobuf for pairing traffic.
    static func encodePairing(message: Message) -> Data? {
        try? message.serializedData()
    }

    /// Serialize and encrypt with the group key for trusted traffic.
    static func encodeSecure(message: Message, groupKey: SymmetricKey) -> Data? {
        guard let serialized = try? message.serializedData() else { return nil }
        return try? CryptoEngine.encrypt(serialized, using: groupKey)
    }

    private static func isPairingMessage(_ message: Message) -> Bool {
        guard let payload = message.payload else { return false }

        switch payload {
        case .identity, .handshake:
            return true
        default:
            return false
        }
    }
}
