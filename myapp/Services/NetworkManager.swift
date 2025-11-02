import Network
import CryptoKit
import OSLog

final class NetworkManager{
    static let shared = NetworkManager()
    
    private var deviceId:String = ""
    private var kDeviceId = "passover.deviceId"
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var symmetricKey:SymmetricKey?
    private weak var pairingManager: PairingManager?
    
    var onClipboardMessage: ((ClipboardMessage) -> Void)?
    
    private init() {
        deviceId = UserDefaults.standard.string(forKey: kDeviceId) ?? ""
    }
    
    func configure(pairingManager: PairingManager){
        self.pairingManager = pairingManager
    }
    
    func start(port: UInt16 = 9999){
        if deviceId == ""{
            Logger.connection.error("DeviceId not found in network manager!")
            return
        }
        
        let options = NWProtocolWebSocket.Options()
        let paramenters = NWParameters.tcp
        paramenters.includePeerToPeer = true
        paramenters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            Logger.connection.error("Invalid Port")
            return
        }
        
        do{
            listener = try NWListener(using: paramenters, on: nwPort)
        }catch{
            Logger.connection.error("Failed to start NWListener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            switch newState{
            case .ready:
                Logger.connection.info("Websocket server started and listening on port: \(port)")
                let txt = NWTXTRecord(["deviceId": deviceId])
                listener?.service = NWListener.Service(name: "Passover", type: "_passover._tcp", domain: "local", txtRecord: txt)
            case .failed(let error):
                Logger.connection.error("Failed to start NWListener: \(error)")
                self.close()
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
        
        listener?.start(queue: .main)
    }
    
    func close(){
        for client in self.connections{
            client.cancel()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        Logger.connection.info("WS Listener closed!")
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
        connection.start(queue: .main)
    }
    
    private func receive(on connection: NWConnection){
        connection.receiveMessage{ [weak self] (content, context, isComplete, error) in
            guard let self = self else { return }
            if error != nil {
                self.removeConnection(connection)
                return
            }
            
            guard let pairingManager = self.pairingManager else {
                Logger.connection.error("Pairing manager is nil")
                return
            }
            
            let keyToTry = pairingManager.isKeySaved ? loadEcryptionKey() : pairingManager.currentEncryptionKey
            
            guard let key = keyToTry else {
                Logger.connection.error("Failed to get key to decrypt data")
                return
            }
            
            if let data = content, !data.isEmpty {
                do{
                    let decryptedData = try KeyStore.decrypt(data, using: key)
                    let message = try Message(serializedBytes: decryptedData)
                    
                    if !verifyConnection(data: message){
                        removeConnection(connection)
                        return
                    }
                    
                    onReceive(message, from: connection)
                }catch{
                    Logger.connection.error("Removing connection, Failed to encrypt data due to \(error)")
                    removeConnection(connection)
                }
            }
            
            if connection.state == .ready {
                self.receive(on: connection)
            }
        }
    }
    
    private func verifyConnection(data: Message) -> Bool{
        guard let pairingManager = self.pairingManager else {
            Logger.connection.error("Pairing manager is nil")
            return false
        }
        
        if pairingManager.isKeySaved{
            return true
        }
        guard case .identity(let identity) = data.payload else{
            Logger.connection.error("First message should be identity message only!")
            return false
        }
        
        if identity.deviceID != self.deviceId{
            return false
        }
        
        pairingManager.saveEncryptionKey()
        Logger.connection.info("First message received, device is paired!")
        return true
    }
    
    private func removeConnection(_ connection: NWConnection){
        connection.cancel()
        connections.removeAll { $0.endpoint == connection.endpoint }
    }
    
    private func loadEcryptionKey()->SymmetricKey?{
        if symmetricKey != nil { return symmetricKey}
        do{
            symmetricKey = try KeyStore.getKey(deviceID: deviceId)
            return symmetricKey
        }catch{
            Logger.connection.error("Failed to fetch symmetric key, can't start the server!, error: \(error)")
            return nil
        }
    }
    
    private func onReceive(_ message: Message, from connection: NWConnection){
        if let payload = message.payload {
            switch payload {
            case .clipboard(let clipboard):
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
            
            case .qrPayload(let qrp):
                print("QR Payload:", qrp)

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
        
        guard let key = loadEcryptionKey() else {
            Logger.connection.error("Encryption key not found!")
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
