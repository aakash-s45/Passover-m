import Foundation
import Network

class FileReceiver: ObservableObject {
    private var listener: NWListener?
    
    func startServer(port: UInt16 = 9999) {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("Failed to start listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { connection in
            connection.start(queue: .main)
            self.receiveFile(connection: connection)
        }

        listener?.start(queue: .main)
        print("Listening on port \(port)")
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

    func stopServer() {
        listener?.cancel()
        print("Server stopped")
    }
}
