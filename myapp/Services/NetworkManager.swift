//
//  NetworkManager.swift
//  Passover
//
//  Created by Aakash Solanki on 05/07/25.
//

import Network
import OSLog

class NetworkManager {
    static let shared = NetworkManager()
    
    let port: NWEndpoint.Port
    let listener: NWListener
    
    var activeConnections: [NWEndpoint: String] = [:]

    
    init?(port: UInt16 = 9999){
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            Logger.connection.warning("Invalid Port")
            return nil
        }
        
        self.port = nwPort
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        do{
            self.listener = try NWListener(using: parameters, on: self.port)
        }catch{
            Logger.connection.warning("failed to create listener: \(error)")
            return nil
        }
        
        listener.service = NWListener.Service(name: "Passover", type: "_passover._tcp", domain: "local")
        
        listener.serviceRegistrationUpdateHandler = { registrationUpdate in
            Logger.connection.info("Service registration")
            print("Service registration: ", registrationUpdate)
        }
        
        start()
    }
    
    func start(){
        listener.stateUpdateHandler = { state in
            print("Listener state: ", state)
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            print("Accepted connection from", connection.endpoint)
            self?.handleConnection(connection)
        }
        
        listener.start(queue: .main)
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
                
            case .failed(let error):
                print("Connection failed:", error.localizedDescription)
                self?.activeConnections.removeValue(forKey: connection.endpoint)
                
            default:
                break
            }
        }

        connection.start(queue: .main)
        connection.start(queue: .global())
        receiveFile(connection: connection)
    }
    
    private func receiveFile(connection: NWConnection) {
        var receivedData = Data()
        
        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1_000_000) { data, _, isComplete, error in
                if let data = data {
                    receivedData.append(data)
                }
                
                if isComplete || error != nil {
                    if receivedData.count > 0 {
                        self.saveFile(data: receivedData)
                    }
                    connection.cancel()
                } else {
                    receiveMore()
                }
            }
        }
        
        receiveMore()
    }
    
    private func saveFile(data: Data) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = detectFileType(data: data)
        let fileName = "screenshot_\(timestamp).\(fileExtension)"
        
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("✅ File saved: \(fileName) (\(data.count) bytes)")
        } catch {
            print("❌ Failed to save file: \(error)")
        }
    }
    
    private func detectFileType(data: Data) -> String {
        guard data.count >= 4 else { return "dat" }
        
        let bytes = data.prefix(4)
        
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpg"
        }
        
        return "png" // Default to png for screenshots
    }

    func stop() {
        listener.cancel()
    }
}
