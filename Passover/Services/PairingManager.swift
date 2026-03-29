import Foundation
import SwiftUI
import OSLog

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

    /// AppDelegate sets this to present the pairing panel on incoming requests.
    var onPairingRequest: (() -> Void)?
    var onConfirmPairing: (() -> Void)?
    var onRejectPairing: (() -> Void)?
    var onRemoveTrustedPeer: ((String) -> Void)?

    init() {
        getOrGenerateDeviceId()
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

    // ── Pairing UI State ──────────────────────────────────────────────────

    func presentPairingRequest(peerName: String, sasCode: String) {
        pendingPeerName = peerName
        self.sasCode = sasCode
        pairingState = .awaitingSasConfirmation
        onPairingRequest?()
    }

    func confirmSas() {
        guard pairingState == .awaitingSasConfirmation else {
            Logger.connection.error("No pending pairing request to confirm")
            return
        }
        onConfirmPairing?()
    }

    func rejectSas() {
        onRejectPairing?()
        resetPairingState()
        Logger.connection.info("SAS rejected by user")
    }

    func markPaired() {
        pairingState = .paired
    }

    func markError(_ message: String) {
        pairingState = .error(message)
    }

    func resetPairingState() {
        pendingPeerName = ""
        sasCode = ""
        pairingState = .idle
    }

    // ── Trusted Peers ─────────────────────────────────────────────────────

    func setTrustedPeers(_ trustedPeers: [TrustedPeerStore.TrustedPeer]) {
        self.trustedPeers = trustedPeers
    }

    func removeTrustedPeer(deviceId: String) {
        onRemoveTrustedPeer?(deviceId)
    }
}
