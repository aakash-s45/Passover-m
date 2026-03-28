import Network
import CryptoKit
import OSLog

final class NetworkManager{
    static let shared = NetworkManager()
    
    private var deviceId:String = ""
    private var kDeviceId = "passover.deviceId"
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var groupKey: SymmetricKey?
    private weak var pairingManager: PairingManager?
    private let networkQueue = DispatchQueue(label: "com.local.passover.network", qos: .userInitiated)
    private var monitor: NWPathMonitor?
    
    var onClipboardMessage: ((ClipboardMessage) -> Void)?
    
    private init() {
        deviceId = UserDefaults.standard.string(forKey: kDeviceId) ?? ""
    }
    
    func configure(pairingManager: PairingManager){
        self.pairingManager = pairingManager
    }
    
    func reloadGroupKey() {
        if KeyStore.hasGroupKey() {
            groupKey = KeyStore.getOrCreateGroupKey()
        }
    }
    
    func start(){
        if listener != nil {
            listener?.cancel()
            listener = nil
        }
        
        if KeyStore.hasGroupKey() {
            groupKey = KeyStore.getOrCreateGroupKey()
        }
        
        startMonitor()
        startListener()
    }
    
    /// Sets up and starts the NWListener with mDNS service registration.
    private func startListener() {
        if deviceId == ""{
            Logger.connection.error("DeviceId not found in network manager!")
            return
        }
        
        let options = NWProtocolWebSocket.Options()
        let paramenters = NWParameters.tcp
        paramenters.includePeerToPeer = true
        paramenters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        
        guard let nwPort = NWEndpoint.Port(rawValue: 0) else {
            Logger.connection.error("Invalid Port")
            return
        }
        
        do{
            let txt = NWTXTRecord(["deviceId": deviceId])
            listener = try NWListener(using: paramenters, on: nwPort)
            listener?.service = NWListener.Service(
                name: "Passover",
                type: "_passover._tcp",
                domain: "local",
                txtRecord: txt
            )
        }catch{
            Logger.connection.error("Failed to start NWListener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            switch newState{
            case .ready:
                Logger.connection.info("Websocket server started and listening on port: \(nwPort.rawValue), device: \(deviceId)")
            case .failed(let error):
                Logger.connection.error("Failed to start NWListener: \(error)")
                self.close()
            case .cancelled:
                Logger.connection.error("Listener cancelled")
            default:
                break
            }
        }
        
        listener?.serviceRegistrationUpdateHandler = { registrationUpdate in
            Logger.connection.info("Service registration")
        }
        
        listener?.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }
        
        listener?.start(queue: networkQueue)
    }
    
    /// Stops the server (listener + connections) but keeps the network monitor alive.
    private func stopServer() {
        for client in self.connections {
            client.cancel()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        Logger.connection.info("Server stopped (monitor still active)")
    }
    
    /// Stops everything — server, connections, and the network monitor.
    func close() {
        stopServer()
        monitor?.cancel()
        monitor = nil
        Logger.connection.info("Fully closed (monitor cancelled)")
    }
    
    /// Creates a fresh NWPathMonitor and starts it.
    private func startMonitor() {
        guard monitor == nil else {
            Logger.connection.debug("Monitor already running, skipping")
            return
        }
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Logger.connection.info("Network restored, restarting server")
                self?.restartServer()
            } else {
                Logger.connection.warning("No network connection, stopping server")
                self?.stopServer()
            }
        }
        newMonitor.start(queue: .main)
        self.monitor = newMonitor
    }
    
    /// Restarts just the server (listener + mDNS). Called when WiFi returns.
    private func restartServer() {
        guard listener == nil else {
            Logger.connection.debug("Server already running, skipping restart")
            return
        }
        startListener()
    }
    
    
    private func handleNewConnection(_ connection: NWConnection){
        connections.append(connection)
        
        connection.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            switch newState {
            case .ready:
                Logger.connection.info("Client \(connection.endpoint.debugDescription) connected!")
                self.receive(on : connection)
            case .failed, .cancelled:
                self.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: networkQueue)
    }
    
    private func receive(on connection: NWConnection){
        connection.receiveMessage{ [weak self] (content, context, isComplete, error) in
            guard let self = self else { return }
            if error != nil {
                self.removeConnection(connection)
                return
            }
            
            if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata{
                if metadata.opcode == .close{
                    Logger.connection.info("Received Close Frame. Closing connection.")
                    self.removeConnection(connection)
                    return
                }
            }
            
            guard let data = content, !data.isEmpty else {
                if connection.state == .ready {
                    self.receive(on: connection)
                }
                return
            }
            
            // Trusted peers: decrypt with group key
            if let key = self.groupKey {
                do {
                    let decryptedData = try KeyStore.decrypt(data, using: key)
                    let message = try Message(serializedBytes: decryptedData)
                    self.onReceive(message, from: connection)
                    
                    if connection.state == .ready {
                        self.receive(on: connection)
                    }
                    return
                } catch {
                    Logger.connection.debug("GroupKey decrypt failed, trying as pairing message")
                }
            }
            
            // Pairing: plain protobuf (Identity or Handshake)
            do {
                let message = try Message(serializedBytes: data)
                if case .identity(let identity) = message.payload {
                    Logger.connection.info("Received pairing Identity from \(identity.deviceName)")
                    
                    if let pairingManager = self.pairingManager {
                        let ourIdentity = pairingManager.buildIdentityMessage()
                        if let serialized = try? ourIdentity.serializedData() {
                            let meta = NWProtocolWebSocket.Metadata(opcode: .binary)
                            let ctx = NWConnection.ContentContext(identifier: "identity-reply", metadata: [meta])
                            connection.send(content: serialized, contentContext: ctx, isComplete: true, completion: .contentProcessed { err in
                                if let err = err {
                                    Logger.connection.error("Failed to send identity: \(err)")
                                }
                            })
                        }
                        
                        pairingManager.handleIncomingIdentity(identity, connection: connection)
                    }
                } else if case .handshake(let handshake) = message.payload {
                    if let pairingManager = self.pairingManager {
                        pairingManager.handleIncomingHandshake(handshake)
                        self.groupKey = KeyStore.getOrCreateGroupKey()
                    }
                }
            } catch {
                Logger.connection.warning("Failed to parse message as pairing data: \(error)")
            }
            
            if connection.state == .ready {
                self.receive(on: connection)
            }
        }
    }
    
    private func removeConnection(_ connection: NWConnection){
        Logger.connection.info("Removing connection: \(connection.endpoint.debugDescription), state: \(String(describing: connection.state))")
        connection.cancel()
        connections.removeAll { $0.endpoint == connection.endpoint }
    }
    
    private func onReceive(_ message: Message, from connection: NWConnection){
        if let payload = message.payload {
            switch payload {
            case .clipboard(let clipboard):
                Logger.connection.info("Received clipboard data")
                onClipboardMessage?(clipboard)

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

            case .handshake(let hs):
                Logger.connection.info("Received handshake message")

            case .identity(let id):
                Logger.connection.info("Received Identity: \(id.deviceID)")
            }
        } else {
            print("Message has no payload")
        }
    }
    
    private func send(data: Data){
        guard !connections.isEmpty else {
            Logger.connection.warning("No active connections to send data")
            return
        }
        
        guard let key = groupKey else {
            Logger.connection.error("No group key available for encryption!")
            return
        }
        do{
            let encryptedData = try KeyStore.encrypt(data, using: key)
            
            let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
            let context = NWConnection.ContentContext(identifier: "websocket-send", metadata: [metadata])
            
            let targets = connections.filter { $0.state == .ready }
            if targets.isEmpty {
                Logger.connection.warning("No ready connections to send data")
            }
            
            for connection in targets {
                connection.send(content: encryptedData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                    if let error = error {
                        Logger.connection.error("Send failed to \(connection.endpoint.debugDescription): \(error.localizedDescription)")
                        self.removeConnection(connection)
                    } else {
                        Logger.connection.debug("Sent \(encryptedData.count) bytes to \(connection.endpoint.debugDescription)")
                    }
                })
            }
        }catch{
            Logger.connection.error("Failed to encrypt data due to \(error)")
            return
        }
    }
    
    private func sendMessage(_ message: Message) {
        do{
            let serializedData = try message.serializedData()
            send(data: serializedData)
        }catch{
            Logger.connection.error("Failed to send message due to error: \(error)")
        }
    }
    
    func sendClipboardData(data: ClipboardMessage) {
        let message = Message.with{
            $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
            $0.payload = .clipboard(data)
        }
        
        sendMessage(message)
    }
}
