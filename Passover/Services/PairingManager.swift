import Foundation
import SwiftUI
import CryptoKit
import OSLog
import Network

class PairingManager: ObservableObject {
    
    @Published var deviceId: String = ""
    @Published var deviceName: String = Host.current().localizedName ?? "Mac"
    @Published var pairingState: PairingState = .idle
    @Published var sasCode: String = ""
    @Published var pendingPeerName: String = ""
    @Published var trustedPeers: [TrustedPeerStore.TrustedPeer] = []
    
    enum PairingState: Equatable {
        case idle
        case awaitingSasConfirmation
        case paired
        case error(String)
    }
    
    private var kDeviceId = "passover.deviceId"
    private(set) var pendingPeerIdentity: Identity?
    private var pairingConnection: NWConnection?
    
    /// AppDelegate sets this to present the pairing panel on incoming requests.
    var onPairingRequest: (() -> Void)?
    
    init() {
        getOrGenerateDeviceId()
        refreshTrustedPeers()
    }
    
    deinit {
        Logger.ui.info("PairingManager is stopping")
    }
    
    // ── Device Identity ───────────────────────────────────────────────────
    
    private func getOrGenerateDeviceId() {
        if let storedId = UserDefaults.standard.string(forKey: kDeviceId) {
            deviceId = storedId
            Logger.ui.info("Loaded deviceId from UserDefaults")
        } else {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: kDeviceId)
            Logger.ui.info("Generated and saved new Device ID")
        }
    }
    
    func buildIdentityMessage() -> Message {
        return Message.with {
            $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
            $0.identity = Identity.with {
                $0.deviceID = deviceId
                $0.deviceName = deviceName
                $0.publicKeyAgreement = KeyStore.getPublicKeyAgreement()
                $0.publicKeySignature = KeyStore.getPublicKeySignature()
            }
        }
    }
    
    // ── Incoming Identity (called from network queue) ─────────────────────
    
    func handleIncomingIdentity(_ identity: Identity, connection: NWConnection) {
        if TrustedPeerStore.shared.isTrusted(deviceId: identity.deviceID) {
            Logger.connection.info("Device \(identity.deviceID) already trusted, skipping SAS")
            return
        }
        
        let localPubKey = KeyStore.getPublicKeyAgreement()
        let remotePubKey = Data(identity.publicKeyAgreement)
        let computedSas = KeyStore.computeSasCode(localPubKey: localPubKey, remotePubKey: remotePubKey)
        let peerName = identity.deviceName.isEmpty ? "Unknown Device" : identity.deviceName
        
        pendingPeerIdentity = identity
        pairingConnection = connection
        
        DispatchQueue.main.async {
            self.sasCode = computedSas
            self.pendingPeerName = peerName
            self.pairingState = .awaitingSasConfirmation
            self.onPairingRequest?()
        }
        
        Logger.connection.info("SAS code computed for \(peerName): \(computedSas)")
    }
    
    // ── SAS Confirmation (called from main thread) ────────────────────────
    
    func confirmSas() {
        guard let identity = pendingPeerIdentity,
              let connection = pairingConnection else {
            Logger.connection.error("No pending identity to confirm")
            return
        }
        
        do {
            let sharedSecret = try KeyStore.computeSharedSecret(peerPublicKeyBytes: Data(identity.publicKeyAgreement))
            let sessionKey = KeyStore.deriveSessionKey(sharedSecret: sharedSecret)
            
            let groupKey = KeyStore.getOrCreateGroupKey()
            let groupKeyData = groupKey.withUnsafeBytes { Data($0) }
            let encryptedGroupKey = try KeyStore.encrypt(groupKeyData, using: sessionKey)
            
            // Plain protobuf — only the encryptedGroupKey field is ciphertext.
            let message = Message.with {
                $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
                $0.handshake = HandshakeMessage.with {
                    $0.sasConfirmed = true
                    $0.encryptedGroupKey = encryptedGroupKey
                }
            }
            
            let serialized = try message.serializedData()
            let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
            let context = NWConnection.ContentContext(identifier: "handshake", metadata: [metadata])
            
            connection.send(content: serialized, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                if let error = error {
                    Logger.connection.error("Failed to send handshake: \(error)")
                }
            })
            
            saveTrustedPeer(identity)
            NetworkManager.shared.reloadGroupKey()
            pairingState = .paired
            refreshTrustedPeers()
            
            Logger.connection.info("SAS confirmed, paired with \(identity.deviceName)")
            
        } catch {
            Logger.connection.error("SAS confirmation failed: \(error)")
            pairingState = .error("Pairing failed: \(error.localizedDescription)")
        }
        
        pendingPeerIdentity = nil
        pairingConnection = nil
    }
    
    func rejectSas() {
        pendingPeerIdentity = nil
        pairingConnection = nil
        pairingState = .idle
        Logger.connection.info("SAS rejected by user")
    }
    
    // ── Incoming Handshake (called from network queue) ────────────────────
    
    func handleIncomingHandshake(_ handshake: HandshakeMessage) {
        guard let peerIdentity = pendingPeerIdentity else { return }
        guard handshake.sasConfirmed, !handshake.encryptedGroupKey.isEmpty else { return }
        
        do {
            let sharedSecret = try KeyStore.computeSharedSecret(peerPublicKeyBytes: Data(peerIdentity.publicKeyAgreement))
            let sessionKey = KeyStore.deriveSessionKey(sharedSecret: sharedSecret)
            let groupKeyBytes = try KeyStore.decrypt(Data(handshake.encryptedGroupKey), using: sessionKey)
            KeyStore.saveGroupKey(SymmetricKey(data: groupKeyBytes))
            Logger.connection.info("Received and saved group key from peer")
        } catch {
            Logger.connection.error("Failed to decrypt peer's group key: \(error)")
        }
    }
    
    // ── Trusted Peers ─────────────────────────────────────────────────────
    
    private func saveTrustedPeer(_ identity: Identity) {
        let peer = TrustedPeerStore.TrustedPeer(
            deviceId: identity.deviceID,
            deviceName: identity.deviceName,
            publicKeyAgreement: Data(identity.publicKeyAgreement),
            publicKeySignature: Data(identity.publicKeySignature),
            trustedAt: Date()
        )
        TrustedPeerStore.shared.addPeer(peer)
    }
    
    func refreshTrustedPeers() {
        trustedPeers = TrustedPeerStore.shared.getAllPeers()
    }
    
    func removeTrustedPeer(deviceId: String) {
        TrustedPeerStore.shared.removePeer(deviceId: deviceId)
        refreshTrustedPeers()
    }
}
