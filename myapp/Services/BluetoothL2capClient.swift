////
////  BluetoothL2capClient.swift
////  Passover
////
////  Created by Aakash Solanki on 22/07/25.
////
//
//
//import Foundation
//import CoreBluetooth
//import Combine
//import OSLog
//import AppKit
//
//class BluetoothL2capClient: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, StreamDelegate {
//    static let shared = BluetoothL2capClient()
//    
//    @Published var status = "Disconnected"
//    @Published var deviceName = ""
//    @Published var isConnected: Bool = false
//    @Published var discoveredPeripherals: [CBPeripheral:CBL2CAPPSM] = [:]
//    
//    private let bluetoothQueue = DispatchQueue(label: "com.passover.bluetooth-queue")
//    
//    private enum ConnectionState{
//        case idle
//        case scanning
//        case connecting(CBPeripheral)
//        case connected(CBPeripheral, CBL2CAPChannel)
//    }
//    
//    private var state: ConnectionState = .idle{
//        didSet{
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//                switch self.state {
//                case .idle:
//                    self.isConnected = false
//                    self.status = "Disconnected"
//                    self.deviceName = ""
//                case .scanning:
//                    self.isConnected = false
//                    self.status = "Scanning..."
//                    self.deviceName = ""
//                case .connecting(let peripheral):
//                    self.isConnected = false
//                    self.status = "Connecting to \(peripheral.name ?? "device")..."
//                    self.deviceName = peripheral.name ?? "Unknown"
//                case .connected(let peripheral, _):
//                    self.isConnected = true
//                    self.status = "Connected"
//                    self.deviceName = peripheral.name ?? "Unknown"
//                }
//            }
//        }
//    }
//    
//    private var centralManager: CBCentralManager!
//    private let userPreferences: UserPreferences
//    private var psm: CBL2CAPPSM?
//    private var connectingPeripheral: CBPeripheral?
//    
//    private var expectedDataSize: Int?
//    private var receivedData = Data()
//    private var sendingQueue: [Data] = []
//    private let queueLock = NSLock()
//    private var streamThread: Thread!
//    private var isThreadRunning = false
//
//
//    override init() {
//        self.userPreferences = UserPreferences()
//        super.init()
//        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue)
//
//        streamThread = Thread(target: self, selector: #selector(threadEntryPoint), object: nil)
//        streamThread.name = "com.passover.stream-thread"
//        streamThread.start()
//        
//        setupSystemEventListeners()
//    }
//    
//    
//    deinit{
//        NSWorkspace.shared.notificationCenter.removeObserver(self)
//    }
//
//    @objc private func threadEntryPoint(){
//        RunLoop.current.add(NSMachPort(), forMode: .default)
//        isThreadRunning = true
//        
//        while isThreadRunning{
//            RunLoop.current.run(until: Date.distantFuture)
//        }
//    }
//
//    func stopStreamThread(){
//        guard isThreadRunning else {return}
//        perform(#selector(stopThreadRunLoop), on: streamThread, with: nil, waitUntilDone: true)
//    }
//
//    @objc private func stopThreadRunLoop(){
//        isThreadRunning = false
//    }
//    
//    private func setupSystemEventListeners(){
//        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
//        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
//    }
//    
//    @objc private func systemWillSleep(){
//        Logger.connection.info("System will sleep. Disconnecting gracefully.")
//        self.disconnect(restartScan: false)
//    }
//    
//    @objc private func systemDidWake(){
//        Logger.connection.info("System did wake. Starting scan.")
//        _ = self.startScan()
//    }
//    
//    func startScan()->Bool {
//        guard centralManager.state == .poweredOn else {
//            Logger.connection.info("Cannot Scan – Bluetooth not powered on")
//            return false
//        }
//        
//        bluetoothQueue.async {
//            guard case .scanning = self.state else {
//                self.state = .scanning
//                self.centralManager.scanForPeripherals(withServices: [L2CAP_SERVICE_UUID], options: nil)
//                DispatchQueue.main.async { [weak self] in
//                    self?.discoveredPeripherals.removeAll()
//                }
//                Logger.connection.info("Started scanning...")
//                return
//            }
//        }
//        return true
//    }
//    
//    func manualDisconnect(){
//        Logger.connection.info("Manual disconnect initiated.")
//        self.disconnect(restartScan: false)
//    }
//    
//// MARK: - core bluetooth logic
//    func centralManagerDidUpdateState(_ central: CBCentralManager) {
//        switch central.state {
//        case .poweredOn:
//            DispatchQueue.main.async {[weak self] in
//                self?.status = "Ready to Scan"
//            }
//            if case .idle = self.state{
//                print("Current state: \(state)")
//                _ = self.startScan()
//            }
//        default:
//            DispatchQueue.main.async {[weak self] in
//                self?.status = "Bluetooth is not available"
//            }
//            self.state = .idle
//        }
//    }
//
//    
//    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        guard discoveredPeripherals[peripheral] == nil else { return }
//        
//        // Extract PSM from advertisement data
//        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
//           let psmData = serviceData[L2CAP_SERVICE_UUID] {
//            // PSM is a 16-bit unsigned integer (UInt16) sent in little-endian format
//            let parsedPSM = psmData.withUnsafeBytes { $0.load(as: UInt16.self) }
//            
//            DispatchQueue.main.async { [weak self] in
//                self?.discoveredPeripherals[peripheral] = parsedPSM
//            }
//            
//            if peripheral.identifier.uuidString == userPreferences.get() ?? "" {
//                Logger.connection.info("Found saved device, connecting...")
//                self.connect(to: peripheral, using: parsedPSM, saveUUID: false)
//            }
//        }
//    }
//    
//    
//    func connect(to peripheral: CBPeripheral, using psm: UInt16, saveUUID: Bool = true){
//        self.psm = psm
//        self.state = .connecting(peripheral)
//        centralManager.stopScan()
//        self.connectingPeripheral = peripheral
//        
//        if saveUUID {
//            userPreferences.update(identifier: peripheral.identifier.uuidString)
//        }
//        centralManager.connect(peripheral, options: nil)
//    }
//
//    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        peripheral.delegate = self
//        self.connectingPeripheral = nil
//        
//        // Open L2CAP channel using the discovered PSM
//        if let psm = self.psm {
//            peripheral.openL2CAPChannel(psm)
//        } else {
//            disconnect(restartScan: true)
//        }
//    }
//    
//    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
//        Logger.connection.error("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
//        self.connectingPeripheral = nil
//        disconnect(restartScan: true)
//    }
//    
//    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
//        Logger.connection.info("Disconnected from \(peripheral.name ?? "Unknown")")
//        self.connectingPeripheral = nil
//        disconnect(restartScan: true)
//    }
//    
//  
//    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
//        if let error = error {
//            Logger.connection.error("L2CAP channel error: \(error.localizedDescription)")
//            disconnect(restartScan: true)
//            return
//        }
//        guard let channel = channel else {
//            disconnect(restartScan: true)
//            return
//        }
//
//        self.perform(#selector(setupStreamsOnThread), on: streamThread, with: channel, waitUntilDone: false)
//        self.state = .connected(peripheral, channel)
//    }
//    
//    @objc private func setupStreamsOnThread(channel: CBL2CAPChannel){
//        channel.inputStream.delegate = self
//        channel.outputStream.delegate = self
//        
//        channel.inputStream.schedule(in: .current, forMode: .default)
//        channel.outputStream.schedule(in: .current, forMode: .default)
//        
//        channel.inputStream.open()
//        channel.outputStream.open()
//    }
//    
//    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
//        switch eventCode {
//        case .hasBytesAvailable:
//            if let inputStream = aStream as? InputStream {
//                readAvailableBytes(from: inputStream)
//            }
//            
//        case .hasSpaceAvailable:
//            if case .connected(_, let channel) = self.state{
//                if aStream == channel.outputStream {
//                    processSendQueue()
//                }
//            }
//            
//            
//        case .endEncountered, .errorOccurred:
//            if eventCode == .errorOccurred {
//                Logger.connection.error("Stream error: \(aStream.streamError!)")
//            }
//            bluetoothQueue.async { [weak self] in
//                self?.disconnect(restartScan: true)
//            }
//            
//        default:
//            break
//        }
//    }
//    
//    private func readAvailableBytes(from inputStream: InputStream) {
//        let bufferSize = 2048
//        var buffer = [UInt8](repeating: 0, count: bufferSize)
//        
//        // Keep reading while there are bytes available
//        while inputStream.hasBytesAvailable {
//            let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
//            if bytesRead > 0{
//                // Append the new data
//                receivedData.append(buffer, count: bytesRead)
//            } else{
//                if let error = inputStream.streamError {
//                     Logger.connection.error("Stream read error: \(error)")
//                     return
//                }
//                break
//            }
//        }
//        
//        processDataBuffer()
//    }
//    
//    private func processDataBuffer() {
//        if expectedDataSize == nil {
//            // at least 4 bytes for header
//            guard receivedData.count >= 4 else {return}
//            
//            let sizeData = receivedData.prefix(4)
//            let bytes = Array(sizeData)
//            guard bytes.count == 4 else {
//                Logger.connection.error("Invalid header size: \(bytes.count)")
//                return
//            }
//            
//            // Manually construct UInt32 from bytes (big-endian order)
//            // Android's ByteBuffer.putInt() writes in big-endian (network byte order)
//            let lengthInBigEndian = (UInt32(bytes[0]) << 24) |
//            (UInt32(bytes[1]) << 16) |
//            (UInt32(bytes[2]) << 8)  |
//            (UInt32(bytes[3]))
//            
//            let length = Int(lengthInBigEndian)
//            guard length > 0 && length <= 10_000_000 else { // 10MB max
//                Logger.connection.error("Received invalid message length: \(length). Protocol error - clearing buffer.")
//                Logger.connection.error("Raw bytes: \(sizeData.map { String(format: "%02x", $0) }.joined(separator: " "))")
//                
//                self.receivedData.removeAll()
//                self.expectedDataSize = nil
//                return
//            }
//            
//            Logger.connection.info("Expecting new message with length: \(length) bytes.")
//            self.expectedDataSize = length
//            receivedData.removeFirst(4)
//        }
//        
//        guard let expectedSize = expectedDataSize, expectedSize > 0 else {
//            Logger.connection.warning("No expected data size (header not received yet)")
//            self.expectedDataSize = nil
//            return
//        }
//        
//        guard receivedData.count >= expectedSize else {return}
//        
//        let messageData = Data(receivedData.prefix(expectedSize))
//        Logger.connection.info("Complete message of size \(messageData.count).")
//        updateClipboard(data: messageData)
//        
//        receivedData.removeFirst(expectedSize)
//        expectedDataSize = nil
//
//        if !receivedData.isEmpty {processDataBuffer()}
//    }
//    
//    func send(data: Data) {
//        // Create the complete packet with the size header
//        var dataSize = UInt32(data.count).bigEndian
//        let sizeData = Data(bytes: &dataSize, count: MemoryLayout<UInt32>.size)
//        let packet = sizeData + data
//        
//        Logger.connection.info("Sending data")
//
//        // Add the packet to the queue safely
//        queueLock.lock()
//        sendingQueue.append(packet)
//        queueLock.unlock()
//        
//        perform(#selector(processSendQueue), on: streamThread, with: nil, waitUntilDone: false)
//    }
//    
//    @objc private func processSendQueue() {
//        queueLock.lock()
//        defer { queueLock.unlock() }
//
//        guard !sendingQueue.isEmpty, case .connected(_, let channel) = self.state, let outputStream = channel.outputStream, outputStream.hasSpaceAvailable else {
//            Logger.connection.info("Not processing send queue")
//            return
//        }
//    
//
//        while !sendingQueue.isEmpty && outputStream.hasSpaceAvailable {
//            let dataToSend = sendingQueue[0]
//            let bytesWritten = dataToSend.withUnsafeBytes {
//                outputStream.write($0.baseAddress!, maxLength: dataToSend.count)
//            }
//
//            if bytesWritten > 0 {
//                sendingQueue[0].removeFirst(bytesWritten)
//                if sendingQueue[0].isEmpty {
//                    sendingQueue.removeFirst()
//                }
//            } else if bytesWritten < 0 {
//                if let error = outputStream.streamError {
//                    Logger.connection.error("Stream write error: \(error)")
//                }
//                sendingQueue.removeAll()
//                bluetoothQueue.async { [weak self] in self?.disconnect(restartScan: true) }
//                return
//            } else {
//                // bytesWritten is 0, the buffer is full, so we stop writing for now.
//                // The .hasSpaceAvailable event will trigger us again.
//                break
//            }
//        }
//    }
//    
//        
//    func updateClipboard(data:Data){
//        do{
//            let packet = try BPacket(serializedBytes: data)
//            if(packet.type == MessageType.clipboard){
//                let clipboardData = packet.clipboard
//                ClipboardManager.shared.addDataToClipboard(data: clipboardData)
//                Logger.connection.info("Clipboard data received: \(clipboardData.text)")
//            }
//        }catch let error{
//            Logger.connection.error("Failed to read data using \(data) with error \(error)")
//        }
//    }
//    
//    func disconnect(restartScan doScanAfter:Bool = false) {
//        bluetoothQueue.async { [weak self] in
//            guard let self = self else {return}
//            
//            if case .connected(let peripheral, let channel) = self.state{
//                channel.inputStream.close()
//                channel.outputStream.close()
//                
//                if self.centralManager.state == .poweredOn{
//                    self.centralManager.cancelPeripheralConnection(peripheral)
//                }
//            }
//            
//            stopStreamThread()
//            self.sendingQueue.removeAll()
//            self.receivedData.removeAll()
//            self.expectedDataSize = nil
//            
//            if doScanAfter{
//                _ = self.startScan()
//            } else {
//                self.centralManager.stopScan()
//                self.state = .idle
//            }
//                
//        }
//    }
//}
//
//
///*
//
// if connected:
//    show disconnect + remove
// else:
//    start scan
//    show devices
//    if saved:
//        auto connect to saved device
//    else select:
//        save + connect
// 
// 
// 
// clipboard
// - send
// - receive
// 
// ServiceManager
// - bluetooth
// - network
// 
// - send
//    - if small: bluetooth
//    - else: check if same network, share
//        - listener always running in macos or on demand or mdns
// 
//        - send from android
//            - get ip via bluetooth + connect
//            - send
//        - send from macos
//            - send ip to android + ask android to connect
//            - send
// 
// 
//- reasearch on macos side
//    - programatically connect to given wifi
//    - get credentials of current wifi
// 
//- research on anroid side
//    - programatically turn on hotspot with name and password
//    - programaticaly connects to given wifi
// 
// */
