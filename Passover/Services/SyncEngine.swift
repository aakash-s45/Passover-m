import CryptoKit
import Foundation
import Network
import OSLog

/// Coordinates WebSocket transport, `MessageCodec`, clipboard, and pairing — no UI.
final class SyncEngine {
    private struct PendingPairingSession {
        let identity: Identity
        let sendPayload: (Data) -> Void
    }

    private let webSocketServer = WebSocketServer()
    private let stateQueue = DispatchQueue(label: "com.local.passover.syncengine.state", qos: .userInitiated)
    private let pairingManager: PairingManager
    private var clipboardManager: ClipboardManager?
    private var groupKey: SymmetricKey?
    private var pendingPairingSession: PendingPairingSession?

    init(pairingManager: PairingManager) {
        self.pairingManager = pairingManager
        pairingManager.onConfirmPairing = { [weak self] in
            self?.confirmPendingPairing()
        }
        pairingManager.onRejectPairing = { [weak self] in
            self?.rejectPendingPairing()
        }
        pairingManager.onRemoveTrustedPeer = { [weak self] deviceId in
            self?.removeTrustedPeer(deviceId: deviceId)
        }
        webSocketServer.onRawData = { [weak self] connection, data in
            self?.handleRawData(connection: connection, data: data)
        }
        refreshTrustedPeers()
    }

    func start() {
        reloadGroupKey()
        refreshTrustedPeers()
        attachClipboardManagerIfNeeded()

        guard !pairingManager.deviceId.isEmpty else {
            Logger.connection.error("No deviceId; SyncEngine not started")
            return
        }
        webSocketServer.start(deviceId: pairingManager.deviceId)
    }

    func pause() {
        clearPendingPairing()
        detachClipboardManager()
        webSocketServer.stopServer()
    }

    func resume() {
        start()
    }

    func stop() {
        clearPendingPairing()
        detachClipboardManager()
        webSocketServer.close()
    }

    func reloadGroupKey() {
        if KeyStore.hasGroupKey() {
            setGroupKey(KeyStore.getOrCreateGroupKey())
        } else {
            setGroupKey(nil)
        }
    }

    func sendClipboardData(_ data: ClipboardMessage) {
        guard let groupKey = currentGroupKey() else {
            Logger.connection.warning("No group key; clipboard update will not be sent")
            return
        }

        let message = Message.with {
            $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
            $0.payload = .clipboard(data)
        }

        guard let wire = MessageCodec.encodeSecure(message: message, groupKey: groupKey) else {
            Logger.connection.error("Failed to encode clipboard message")
            return
        }
        webSocketServer.broadcast(wire)
    }

    private func handleRawData(connection: NWConnection, data: Data) {
        let groupKey = currentGroupKey()
        guard let wireMessage = MessageCodec.decode(data: data, groupKey: groupKey) else {
            Logger.connection.warning("Could not decode wire data as Message")
            return
        }

        switch wireMessage {
        case .pairing(let message):
            DispatchQueue.main.async { [weak self] in
                self?.handlePairingMessage(message, connection: connection)
            }

        case .secure(let message):
            guard let payload = message.payload else {
                Logger.connection.debug("Message has no payload")
                return
            }
            dispatchAppPayload(payload)
        }
    }

    private func handlePairingMessage(_ message: Message, connection: NWConnection) {
        guard let payload = message.payload else {
            Logger.connection.debug("Message has no payload")
            return
        }

        switch payload {
        case .identity(let identity):
            handlePairingIdentity(identity, connection: connection)
        case .handshake(let handshake):
            handleIncomingHandshake(handshake)
        default:
            Logger.connection.warning("Received unexpected plain pairing payload")
        }
    }

    private func handlePairingIdentity(_ identity: Identity, connection: NWConnection) {
        let ourIdentity = makeIdentityMessage()
        if let payload = MessageCodec.encodePairing(message: ourIdentity) {
            webSocketServer.send(payload, on: connection)
        } else {
            Logger.connection.error("Failed to encode local identity message")
        }

        if TrustedPeerStore.shared.isTrusted(deviceId: identity.deviceID) {
            Logger.connection.info("Device \(identity.deviceID) already trusted, skipping SAS")
            return
        }

        let localPubKey = KeyStore.getPublicKeyAgreement()
        let remotePubKey = Data(identity.publicKeyAgreement)
        let computedSas = CryptoEngine.computeSasCode(localPubKey: localPubKey, remotePubKey: remotePubKey)
        let peerName = identity.deviceName.isEmpty ? "Unknown Device" : identity.deviceName

        setPendingPairingSession(
            PendingPairingSession(identity: identity) { [weak self] payload in
                self?.webSocketServer.send(payload, on: connection)
            }
        )
        pairingManager.presentPairingRequest(peerName: peerName, sasCode: computedSas)
        Logger.connection.info("SAS code computed for \(peerName): \(computedSas)")
    }

    private func confirmPendingPairing() {
        guard let session = currentPendingPairingSession() else {
            Logger.connection.error("No pending identity to confirm")
            return
        }

        do {
            let privateKey = KeyStore.getOrCreateKeyAgreementPair()
            let sharedSecret = try CryptoEngine.computeSharedSecret(
                privateKey: privateKey,
                peerPublicKeyBytes: Data(session.identity.publicKeyAgreement)
            )
            let sessionKey = CryptoEngine.deriveSessionKey(sharedSecret: sharedSecret)
            let groupKey = KeyStore.getOrCreateGroupKey()
            let groupKeyData = groupKey.withUnsafeBytes { Data($0) }
            let encryptedGroupKey = try CryptoEngine.encrypt(groupKeyData, using: sessionKey)

            let message = Message.with {
                $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
                $0.handshake = HandshakeMessage.with {
                    $0.sasConfirmed = true
                    $0.encryptedGroupKey = encryptedGroupKey
                }
            }

            guard let payload = MessageCodec.encodePairing(message: message) else {
                Logger.connection.error("Failed to encode handshake message")
                pairingManager.markError("Pairing failed: could not encode handshake")
                clearPendingPairing(resetUI: false)
                return
            }

            session.sendPayload(payload)
            saveTrustedPeer(session.identity)
            reloadGroupKey()
            refreshTrustedPeers()
            pairingManager.markPaired()
            Logger.connection.info("SAS confirmed, paired with \(session.identity.deviceName)")
        } catch {
            Logger.connection.error("SAS confirmation failed: \(error.localizedDescription)")
            pairingManager.markError("Pairing failed: \(error.localizedDescription)")
        }

        setPendingPairingSession(nil)
    }

    private func rejectPendingPairing() {
        setPendingPairingSession(nil)
    }

    private func handleIncomingHandshake(_ handshake: HandshakeMessage) {
        guard let session = currentPendingPairingSession() else {
            Logger.connection.warning("Received handshake without a pending pairing session")
            return
        }
        guard handshake.sasConfirmed, !handshake.encryptedGroupKey.isEmpty else {
            Logger.connection.warning("Received invalid handshake payload")
            pairingManager.markError("Pairing failed: invalid handshake")
            setPendingPairingSession(nil)
            return
        }

        do {
            let privateKey = KeyStore.getOrCreateKeyAgreementPair()
            let sharedSecret = try CryptoEngine.computeSharedSecret(
                privateKey: privateKey,
                peerPublicKeyBytes: Data(session.identity.publicKeyAgreement)
            )
            let sessionKey = CryptoEngine.deriveSessionKey(sharedSecret: sharedSecret)
            let groupKeyBytes = try CryptoEngine.decrypt(Data(handshake.encryptedGroupKey), using: sessionKey)
            KeyStore.saveGroupKey(SymmetricKey(data: groupKeyBytes))
            saveTrustedPeer(session.identity)
            reloadGroupKey()
            refreshTrustedPeers()
            pairingManager.markPaired()
            Logger.connection.info("Received and saved group key from peer")
        } catch {
            Logger.connection.error("Failed to decrypt peer's group key: \(error.localizedDescription)")
            pairingManager.markError("Pairing failed: \(error.localizedDescription)")
        }

        setPendingPairingSession(nil)
    }

    private func dispatchAppPayload(_ payload: Message.OneOf_Payload) {
        switch payload {
        case .clipboard(let clipboard):
            Logger.connection.info("Received clipboard data")
            DispatchQueue.main.async { [weak self] in
                self?.clipboardManager?.addDataToClipboard(data: clipboard)
            }

        case .mediaControl(let mediaControl):
            print("Media control:", mediaControl)

        case .playbackInfo(let playbackInfo):
            print("Playback info:", playbackInfo)

        case .fileHeader(let fileHeader):
            print("File header:", fileHeader)

        case .fileChunk(let fileChunk):
            print("File chunk:", fileChunk)

        case .statusRequest(let req):
            print("Status request:", req)

        case .statusResponse(let resp):
            print("Status response:", resp)

        case .error(let err):
            print("Error:", err)

        case .videoChunk(let video):
            print("Video chunk:", video)

        case .artwork(let art):
            print("Artwork:", art)

        case .heartbeat(let hb):
            print("Heartbeat:", hb)

        case .handshake, .identity:
            break
        }
    }

    private func attachClipboardManagerIfNeeded() {
        guard clipboardManager == nil else { return }

        let clipboardManager = ClipboardManager()
        clipboardManager.onClipboardUpdate = { [weak self] clipboardData in
            self?.sendClipboardData(clipboardData)
        }
        self.clipboardManager = clipboardManager
    }

    private func detachClipboardManager() {
        clipboardManager?.onClipboardUpdate = nil
        clipboardManager = nil
    }

    private func makeIdentityMessage() -> Message {
        Message.with {
            $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
            $0.identity = Identity.with {
                $0.deviceID = pairingManager.deviceId
                $0.deviceName = pairingManager.deviceName
                $0.publicKeyAgreement = KeyStore.getPublicKeyAgreement()
                $0.publicKeySignature = KeyStore.getPublicKeySignature()
            }
        }
    }

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

    private func removeTrustedPeer(deviceId: String) {
        TrustedPeerStore.shared.removePeer(deviceId: deviceId)
        refreshTrustedPeers()
    }

    private func refreshTrustedPeers() {
        pairingManager.setTrustedPeers(TrustedPeerStore.shared.getAllPeers())
    }

    private func clearPendingPairing(resetUI: Bool = true) {
        setPendingPairingSession(nil)
        if resetUI {
            pairingManager.resetPairingState()
        }
    }

    private func currentGroupKey() -> SymmetricKey? {
        stateQueue.sync { groupKey }
    }

    private func setGroupKey(_ groupKey: SymmetricKey?) {
        stateQueue.sync {
            self.groupKey = groupKey
        }
    }

    private func currentPendingPairingSession() -> PendingPairingSession? {
        stateQueue.sync { pendingPairingSession }
    }

    private func setPendingPairingSession(_ session: PendingPairingSession?) {
        stateQueue.sync {
            pendingPairingSession = session
        }
    }
}
