//
//  BluetoothL2capClient.swift
//  Passover
//
//  Created by Aakash Solanki on 22/07/25.
//


import Foundation
import CoreBluetooth
import Combine
import OSLog

class BluetoothL2capClient: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, StreamDelegate {
    static let shared = BluetoothL2capClient()
    
    @Published var status = "Disconnected"
    @Published var deviceName = ""
    @Published var receivedMessage = ""
    @Published var isConnected: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral:CBL2CAPPSM] = [:]

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var l2capChannel: CBL2CAPChannel?
    
    private let userPreferences: UserPreferences
    private var psm: CBL2CAPPSM?
    
    private var expectedDataSize: Int?
    private var receivedData = Data()
    
    private var sendingQueue: [Data] = []
    private let queueLock = NSLock()
    private let bluetoothQueue = DispatchQueue(label: "com.passover.bluetooth-queue")
    
    private var streamThread: Thread!
    private var isThreadRunning = false

    override init() {
        self.userPreferences = UserPreferences()
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue)
        
        streamThread = Thread(target: self, selector: #selector(threadEntryPoint), object: nil)
        streamThread.name = "com.passover.stream-thread"
        streamThread.start()
    }
    
    @objc private func threadEntryPoint(){
        RunLoop.current.add(NSMachPort(), forMode: .default)
        isThreadRunning = true
        
        while isThreadRunning{
            RunLoop.current.run(until: Date.distantFuture)
        }
    }
    
    func stopStreamThread(){
        guard isThreadRunning else {return}
        perform(#selector(stopThreadRunLoop), on: streamThread, with: nil, waitUntilDone: true)
    }
    
    @objc private func stopThreadRunLoop(){
        isThreadRunning = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            status = "Ready to Scan"
        } else {
            status = "Bluetooth is not available"
        }
    }

    func startScan() {
        Logger.connection.info("Starting scan")
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        status = "Scanning..."
        centralManager.scanForPeripherals(withServices: [L2CAP_SERVICE_UUID], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Extract PSM from advertisement data
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let psmData = serviceData[L2CAP_SERVICE_UUID] {
            
            // PSM is a 16-bit unsigned integer (UInt16) sent in little-endian format
            let parsedPSM = psmData.withUnsafeBytes { $0.load(as: UInt16.self) }
            discoveredPeripherals[peripheral] = parsedPSM
            
            if peripheral.identifier.uuidString == userPreferences.get() ?? "" {
                Logger.connection.info("Connecting to saved device")
                DispatchQueue.main.async { [weak self] in
                    self?.connect(to: peripheral, using: parsedPSM, saveUUID: false)
                }
            }
        }
    }
    
    func connect(to peripheral: CBPeripheral, using psm: UInt16, saveUUID: Bool = true){
        self.psm = psm
        DispatchQueue.main.async { [weak self] in
            self?.status = "Found device: \(peripheral.name ?? "Unknown"), PSM: \(String(describing: self?.psm!))"
        }
        Logger.connection.debug("Found device with PSM: \(self.psm!)")
        
        centralManager.stopScan()
        targetPeripheral = peripheral
        DispatchQueue.main.async { [weak self] in
            self?.deviceName = peripheral.name ?? "Unknown"
        }
        
        discoveredPeripherals.removeAll()
        if saveUUID {
            userPreferences.update(identifier: peripheral.identifier.uuidString)
        }
        
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            self?.status = "Connected. Opening L2CAP Channel..."
        }
        peripheral.delegate = self
        
        // Open L2CAP channel using the discovered PSM
        if let psm = self.psm {
            DispatchQueue.main.async {[weak self] in
                self?.isConnected = true
            }
            peripheral.openL2CAPChannel(psm)
        } else {
            status = "Error: PSM not found."
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        self.isConnected = false
        Logger.connection.info("Disconnected from \(peripheral.name ?? "Unknown")")
    }
    
  
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let error = error {
            self.isConnected = false
            status = "L2CAP channel error: \(error.localizedDescription)"
            return
        }
        guard let channel = channel else {
            self.isConnected = false
            status = "L2CAP channel is nil"
            return
        }
        
        self.perform(#selector(setupStreamsOnThread), on: streamThread, with: channel, waitUntilDone: false)
    }
    
    @objc private func setupStreamsOnThread(channel: CBL2CAPChannel){
        channel.inputStream.delegate = self
        channel.outputStream.delegate = self
        
        channel.inputStream.schedule(in: .current, forMode: .default)
        channel.outputStream.schedule(in: .current, forMode: .default)
        
        channel.inputStream.open()
        channel.outputStream.open()
        
        DispatchQueue.main.async {
            self.l2capChannel = channel
            self.isConnected = true
            self.status = "L2CAP Channel Open!"
        }
    }
    
    private func processSendQueue() {
        queueLock.lock()
        defer { queueLock.unlock() }

        guard !sendingQueue.isEmpty,
              let outputStream = l2capChannel?.outputStream,
              outputStream.hasSpaceAvailable else {
            return
        }

        while !sendingQueue.isEmpty && outputStream.hasSpaceAvailable {
            let bytesWritten = sendingQueue[0].withUnsafeBytes {
                outputStream.write($0.baseAddress!, maxLength: sendingQueue[0].count)
            }

            if bytesWritten > 0 {
                sendingQueue[0].removeFirst(bytesWritten)

                if sendingQueue[0].isEmpty {
                    sendingQueue.removeFirst()
                }
            } else if bytesWritten < 0 {
                Logger.connection.error("Stream write error: \(outputStream.streamError!)")
                sendingQueue.removeAll()
                disconnect(restartScan: true)
                return
            } else {
                // bytesWritten is 0, the buffer is full, so we stop writing for now.
                // The .hasSpaceAvailable event will trigger us again.
                break
            }
        }
    }
    
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            if let inputStream = aStream as? InputStream {
                readAvailableBytes(from: inputStream)
            }
            
        case .hasSpaceAvailable:
            if aStream == l2capChannel?.outputStream {
                processSendQueue()
            }
            
        case .endEncountered:
            DispatchQueue.main.async {
                self.status = "Stream End"
            }
            Logger.connection.warning("L2CAP stream end encountered.")
            disconnect(restartScan: true)
            
        case .errorOccurred:
            DispatchQueue.main.async {
                self.status = "Stream Error"
            }
            Logger.connection.error("L2CAP stream error: \(aStream.streamError?.localizedDescription ?? "Unknown error")")
            
        default:
            break
        }
    }

    private func readAvailableBytes(from inputStream: InputStream) {
        let bufferSize = 2048
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        // Keep reading while there are bytes available
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                Logger.connection.error("Stream read error: \(inputStream.streamError!)")
                return
            } else if bytesRead > 0 {
                // Append the new data
                receivedData.append(buffer, count: bytesRead)
            } else {
                // 0 bytes read might mean end of stream
                break
            }
        }
        
        processDataBuffer()
    }

    private func processDataBuffer() {
        if expectedDataSize == nil {
            // need at least 4 bytes to read the length header.
            guard receivedData.count >= 4 else {
                return // Not enough data for the size prefix yet, wait for more.
            }
            
            // Extract the 4-byte header to determine message length.
            let sizeData = receivedData.prefix(4)
            let bytes = Array(sizeData)
            guard bytes.count == 4 else {
                Logger.connection.error("Invalid header size: \(bytes.count)")
                return
            }
            
            // Manually construct UInt32 from bytes (big-endian order)
            // Android's ByteBuffer.putInt() writes in big-endian (network byte order)
            let lengthInBigEndian = (UInt32(bytes[0]) << 24) |
                                    (UInt32(bytes[1]) << 16) |
                                    (UInt32(bytes[2]) << 8)  |
                                    (UInt32(bytes[3]))
            
            let length = Int(lengthInBigEndian)
            guard length > 0 && length <= 10_000_000 else { // 10MB max
                Logger.connection.error("Received invalid message length: \(length). Protocol error - clearing buffer.")
                Logger.connection.error("Raw bytes: \(sizeData.map { String(format: "%02x", $0) }.joined(separator: " "))")
                
                self.receivedData.removeAll()
                self.expectedDataSize = nil
                return
            }
            
            Logger.connection.info("Expecting new message with length: \(length) bytes.")
            self.expectedDataSize = length
            receivedData.removeFirst(4)
        }
        
        guard let expectedSize = expectedDataSize else {
            Logger.connection.warning("No expected data size (header not received yet)")
            return
        }
        
        guard receivedData.count >= expectedSize else {
            Logger.connection.debug("Waiting for more data, have \(self.receivedData.count), need \(expectedSize)")
            return
        }
        
        let messageData = Data(receivedData.prefix(expectedSize))
        Logger.connection.info("Complete message of size \(messageData.count).")
        updateClipboard(data: messageData)

        receivedData.removeFirst(expectedSize)
        expectedDataSize = nil
        
        if !receivedData.isEmpty {
            processDataBuffer()
        }
    }
    
    func updateClipboard(data:Data){
        do{
            let packet = try BPacket(serializedBytes: data)
            if(packet.type == MessageType.clipboard){
                let clipboardData = packet.clipboard
                ClipboardManager.shared.addDataToClipboard(data: clipboardData)
                Logger.connection.info("Clipboard data received: \(clipboardData.text)")
            }
        }catch let error{
            Logger.connection.error("Failed to read data using \(data) with error \(error)")
        }
    }
    
//    func send(data: Data) {
//        guard let outputStream = l2capChannel?.outputStream, outputStream.hasSpaceAvailable else {
//            status = "Cannot send message."
//            Logger.connection.error("L2CAP channel is not available for writing.")
//            disconnect()
//            return
//        }
//        
//        var dataSize = UInt32(data.count).bigEndian
//        let sizeData = Data(bytes: &dataSize, count: MemoryLayout<UInt32>.size)
//
//        let sizeBytesWritten = sizeData.withUnsafeBytes {
//            outputStream.write($0.baseAddress!, maxLength: sizeData.count)
//        }
//        guard sizeBytesWritten == sizeData.count else {
//            Logger.connection.error("Failed to write size prefix completely.")
//            disconnect()
//            return
//        }
//
//        let dataBytesWritten = data.withUnsafeBytes {
//            outputStream.write($0.baseAddress!, maxLength: data.count)
//        }
//        guard dataBytesWritten == data.count else {
//            Logger.connection.error("Failed to write data payload completely.")
//            return
//        }
//        
//        Logger.connection.info("✅ Successfully queued \(dataBytesWritten) bytes for sending.")
//    }
//    
    
    func send(data: Data) {
        // Create the complete packet with the size header
        var dataSize = UInt32(data.count).bigEndian
        let sizeData = Data(bytes: &dataSize, count: MemoryLayout<UInt32>.size)
        let packet = sizeData + data

        // Add the packet to the queue safely
        queueLock.lock()
        sendingQueue.append(packet)
        queueLock.unlock()

        // Trigger the sending process
        processSendQueue()
    }
    
    
    func disconnect(restartScan doScanAfter:Bool = false) {
        l2capChannel?.inputStream.close()
        l2capChannel?.outputStream.close()
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        status = "Disconnected"
        psm = nil
        targetPeripheral = nil
        l2capChannel = nil
        isConnected = false
        deviceName = ""
        if doScanAfter {
            self.startScan()
        }
    }
}


/*

 if connected:
    show disconnect + remove
 else:
    start scan
    show devices
    if saved:
        auto connect to saved device
    else select:
        save + connect
 
 
 
 clipboard
 - send
 - receive
 
 ServiceManager
 - bluetooth
 - network
 
 - send
    - if small: bluetooth
    - else: check if same network, share
        - listener always running in macos or on demand or mdns
 
        - send from android
            - get ip via bluetooth + connect
            - send
        - send from macos
            - send ip to android + ask android to connect
            - send
 
 
- reasearch on macos side
    - programatically connect to given wifi
    - get credentials of current wifi
 
- research on anroid side
    - programatically turn on hotspot with name and password
    - programaticaly connects to given wifi
 
 */
