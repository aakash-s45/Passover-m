import Foundation
import Network
import OSLog

/// mDNS WebSocket listener: accepts connections and moves raw `Data` — no protobuf or crypto.
final class WebSocketServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let networkQueue = DispatchQueue(label: "com.local.passover.websocket", qos: .userInitiated)
    private var monitor: NWPathMonitor?
    private var deviceId: String = ""

    var onRawData: ((NWConnection, Data) -> Void)?

    func start(deviceId: String) {
        if listener != nil {
            listener?.cancel()
            listener = nil
        }
        guard !deviceId.isEmpty else {
            Logger.connection.error("DeviceId empty; cannot start WebSocket server")
            return
        }
        self.deviceId = deviceId

        startMonitor()
    }

    func stopServer() {
        for client in connections {
            client.cancel()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        Logger.connection.info("WebSocket server stopped (monitor may still run)")
    }

    func close() {
        stopServer()
        monitor?.cancel()
        monitor = nil
        Logger.connection.info("WebSocket server fully closed")
    }

    func send(_ data: Data, on connection: NWConnection) {
        networkQueue.async { [weak self] in
            self?.sendOnQueue(data, on: connection)
        }
    }

    /// Sends already-encoded wire bytes to every ready connection (e.g. encrypted clipboard).
    func broadcast(_ data: Data) {
        networkQueue.async { [weak self] in
            guard let self else { return }
            let targets = self.connections.filter { $0.state == .ready }
            guard !targets.isEmpty else {
                Logger.connection.warning("No ready connections to broadcast")
                return
            }
            for connection in targets {
                self.sendOnQueue(data, on: connection)
            }
        }
    }

    private func sendOnQueue(_ data: Data, on connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "websocket-send", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
            if let error {
                Logger.connection.error("Send failed to \(connection.endpoint.debugDescription): \(error.localizedDescription)")
                self.removeConnection(connection)
            } else {
                Logger.connection.debug("Sent \(data.count) bytes to \(connection.endpoint.debugDescription)")
            }
        })
    }

    private func startListener(deviceId: String) {
        let options = NWProtocolWebSocket.Options()
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)

        guard let nwPort = NWEndpoint.Port(rawValue: 0) else {
            Logger.connection.error("Invalid port")
            return
        }

        do {
            let txt = NWTXTRecord(["deviceId": deviceId])
            listener = try NWListener(using: parameters, on: nwPort)
            listener?.service = NWListener.Service(
                name: "Passover",
                type: "_passover._tcp",
                domain: "local",
                txtRecord: txt
            )
        } catch {
            Logger.connection.error("Failed to create NWListener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                Logger.connection.info("WebSocket listening, device: \(deviceId)")
            case .failed(let err):
                Logger.connection.error("Listener failed: \(err)")
                self.close()
            case .cancelled:
                Logger.connection.error("Listener cancelled")
            default:
                break
            }
        }

        listener?.serviceRegistrationUpdateHandler = { _ in
            Logger.connection.info("mDNS service registration update")
        }

        listener?.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }

        listener?.start(queue: networkQueue)
    }

    private func startMonitor() {
        guard monitor == nil else {
            Logger.connection.debug("Path monitor already running")
            return
        }
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Logger.connection.info("Network path satisfied; restarting listener if needed")
                self?.restartListenerIfNeeded()
            } else {
                Logger.connection.warning("Network path unsatisfied; stopping listener")
                self?.stopServer()
            }
        }
        newMonitor.start(queue: .main)
        monitor = newMonitor
    }

    private func restartListenerIfNeeded() {
        networkQueue.async { [weak self] in
            guard let self, self.listener == nil, !self.deviceId.isEmpty else { return }
            self.startListener(deviceId: self.deviceId)
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                Logger.connection.info("Client connected: \(connection.endpoint.debugDescription)")
                self.receive(on: connection)
            case .failed, .cancelled:
                self.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: networkQueue)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, _, error in
            guard let self else { return }
            if error != nil {
                self.removeConnection(connection)
                return
            }

            if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
               metadata.opcode == .close {
                Logger.connection.info("WebSocket close frame; dropping connection")
                self.removeConnection(connection)
                return
            }

            guard let data = content, !data.isEmpty else {
                if connection.state == .ready {
                    self.receive(on: connection)
                }
                return
            }

            self.onRawData?(connection, data)

            if connection.state == .ready {
                self.receive(on: connection)
            }
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        Logger.connection.info("Removing connection: \(connection.endpoint.debugDescription)")
        connection.cancel()
        connections.removeAll { $0.endpoint == connection.endpoint }
    }
}
