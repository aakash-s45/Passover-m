import Foundation
import OSLog

/// Persistent store for trusted peers, backed by a Codable plist file.
/// All public methods are thread-safe via a serial dispatch queue.
final class TrustedPeerStore {
    
    static let shared = TrustedPeerStore()
    
    struct TrustedPeer: Codable, Identifiable, Equatable {
        let deviceId: String
        let deviceName: String
        let publicKeyAgreement: Data
        let publicKeySignature: Data
        let trustedAt: Date
        
        var id: String { deviceId }
    }
    
    private let fileURL: URL
    private var peers: [TrustedPeer] = []
    private let queue = DispatchQueue(label: "com.local.passover.trustedpeers")
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.local.passover", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("trusted_peers.plist")
        load()
    }
    
    // ── CRUD ──────────────────────────────────────────────────────────────
    
    func addPeer(_ peer: TrustedPeer) {
        queue.sync {
            peers.removeAll { $0.deviceId == peer.deviceId }
            peers.append(peer)
            save()
        }
        Logger.connection.info("Added trusted peer: \(peer.deviceName) (\(peer.deviceId))")
    }
    
    func getPeer(byDeviceId deviceId: String) -> TrustedPeer? {
        queue.sync { peers.first { $0.deviceId == deviceId } }
    }
    
    func getAllPeers() -> [TrustedPeer] {
        queue.sync { peers }
    }
    
    func removePeer(deviceId: String) {
        queue.sync {
            peers.removeAll { $0.deviceId == deviceId }
            save()
        }
        Logger.connection.info("Removed trusted peer: \(deviceId)")
    }
    
    func isTrusted(deviceId: String) -> Bool {
        queue.sync { peers.contains { $0.deviceId == deviceId } }
    }
    
    func clearAll() {
        queue.sync {
            peers.removeAll()
            save()
        }
    }
    
    // ── Persistence ───────────────────────────────────────────────────────
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            peers = try PropertyListDecoder().decode([TrustedPeer].self, from: data)
            Logger.connection.info("Loaded \(self.peers.count) trusted peers")
        } catch {
            Logger.connection.error("Failed to load trusted peers: \(error)")
            peers = []
        }
    }
    
    private func save() {
        do {
            let data = try PropertyListEncoder().encode(peers)
            try data.write(to: fileURL)
        } catch {
            Logger.connection.error("Failed to save trusted peers: \(error)")
        }
    }
}
