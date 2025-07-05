//
//  BluetoothClient.swift
//  myapp
//
//  Created by Aakash Solanki on 14/09/24.
//

import Foundation
import IOBluetooth
import IOBluetoothUI
import CoreBluetooth
import os


class BluetoothClient: NSObject, CBCentralManagerDelegate{
    var isConnected: Bool = false
    var isStopped:Bool = false
    
    var centralManager: CBCentralManager?
    var device: IOBluetoothDevice?
    var backgroundQueue:DispatchQueue
    var rfcommChannel:IOBluetoothRFCOMMChannel?
    var inquiry:IOBluetoothDeviceInquiry?
    var incomingDataBuffer = Data()
    var expectedDataLength: Int?
    
    override init() {
        self.backgroundQueue = DispatchQueue(label: "app.passover.bg", qos: .background)
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: self.backgroundQueue)
        Logger.connection.debug("BluetoothClient init")
    }
    
    deinit{Logger.connection.debug("BluetoothClient deinit")}
    
    func start(){
        guard let device = self.device else{
            Logger.connection.warning("No Gateway proxy found to connect!")
            return
        }
        self.runSDPquery(to: device)
    }
    
    func stop(){
        self.stopInquiry()
        if ConnectionViewModel.shared.is_connected{
            self.attemptCloseRFCOMM(retries: 3)
        }
        self.isStopped = true
    }
    
    func update(device: IOBluetoothDevice){
        self.device = device
    }
    
    
}

extension BluetoothClient{
    func connect(to device:IOBluetoothDevice){
        let status = self.openRFCOMM(to: device)
        if status{
            Logger.connection.info("Connected to \(device.nameOrAddress)")
        }
        else{
            Logger.connection.error("Failed to connect to \(device.nameOrAddress)")
        }
    }
    
    func disconnect(){
        guard let device = self.device else{
            Logger.connection.error("No device selected!")
            return
        }
        if device.isConnected(){
            device.closeConnection()
            Logger.connection.warning("Disconnecting...")
        }
        else{
            Logger.connection.warning("Not connected to device!")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            ConnectionViewModel.shared.update(is_power: true)
            self.connecToSavedDevice()
        case .poweredOff:
            print("Bluetooth is powered off")
            ConnectionViewModel.shared.update(is_power: false)
            self.stop()
        case .resetting:
            print("Bluetooth is resetting")
            self.stop()
        case .unauthorized:
            print("Bluetooth is unauthorized")
            self.stop()
        case .unsupported:
            print("Bluetooth is unsupported on this device")
            self.stop()
        case .unknown:
            print("Bluetooth state is unknown")
            self.stop()
        @unknown default:
            self.stop()
            fatalError()
        }
    }
    
    func connecToSavedDevice(){
        let savedDevice = AppRepository.shared.getExistingDevice()
        if !savedDevice.isEmpty{
            ConnectionViewModel.shared.update(is_device: true)
            ConnectionViewModel.shared.update(savedDevice: savedDevice)
            Logger.connection.debug("Saved device address: \(savedDevice.description)")
//            let device = IOBluetoothDevice(addressString: "98-09-cf-a5-f2-ef")
            if let device = IOBluetoothDevice(addressString: savedDevice[0]){
                self.stopInquiry()
                self.update(device: device)
                self.start()
            }
            else{
                Logger.connection.error("Couldn't conenct to saved device address: \(savedDevice.description)")
            }
        }
        else{
            self.startInquiry()
        }
    }
}


extension BluetoothClient: IOBluetoothDeviceInquiryDelegate{
    
    func startInquiry() {
        Logger.connection.debug("Starting Inquiry")
        self.inquiry = IOBluetoothDeviceInquiry(delegate: self)
        self.inquiry?.start()
        ConnectionViewModel.shared.update(is_scanning: true)
    }
    
    func stopInquiry() {
        inquiry?.stop()
        inquiry = nil
        Logger.connection.debug("Inquiry stopped")
    }
    
    func deviceInquiryStarted(_ sender: IOBluetoothDeviceInquiry!) {
        Logger.connection.debug("Device inquiry: started")
        ConnectionViewModel.shared.update(is_scanning: true)
    }
    
    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        Logger.connection.debug("Device inquiry: completed")
        ConnectionViewModel.shared.update(is_scanning: false)
    }
    
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        Logger.connection.debug("Device inquiry: found device: \(device.debugDescription)")
        ConnectionViewModel.shared.addScanResult(device: device)
    }
    
    func deviceInquiryUpdatingDeviceNamesStarted(_ sender: IOBluetoothDeviceInquiry!, devicesRemaining: UInt32) {
        Logger.connection.debug("Device inquiry: updating device names started")
    }
    
    func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        Logger.connection.debug("Device inquiry: device name udpated")
    }
}



extension BluetoothClient{
    @objc func sdpQueryComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        if status == kIOReturnSuccess {
            print("SDP query completed successfully for device: \(device.name ?? "Unknown Device")")
            // You can now check services or proceed with the RFCOMM channel
            self.connect(to: device)
        } else {
            print("SDP query failed with status: \(status)")
            // Handle failure case
        }
    }
    
    func runSDPquery(to device:IOBluetoothDevice){
        // Perform the SDP query asynchronously
        let sdpStatus = device.performSDPQuery(self)
        if sdpStatus == kIOReturnSuccess {
            Logger.connection.debug("SDP query started successfully. Waiting for completion...")
        } else {
            Logger.connection.debug("Failed to start SDP query with status: \(sdpStatus)")
        }
    }
    
    func openRFCOMM(to device: IOBluetoothDevice)->Bool{
        for service in device.services {
            let serviceRecord = service as! IOBluetoothSDPServiceRecord
            if let name = serviceRecord.getServiceName(){
                var chid = 0
                serviceRecord.getRFCOMMChannelID(&chid)
                Logger.connection.info("\(name) found with channel: \(chid)")
                if name == BLEUtils.serverName{
                    let status = self.openRFCOMM(to: device, with: serviceRecord)
                    return status
                }
            }
        }
        Logger.connection.error("Cound not found channel id for RFCOMM channel")
        return false
    }
    
    func openRFCOMM(to device: IOBluetoothDevice, with service: IOBluetoothSDPServiceRecord) -> Bool {
        var channelID: BluetoothRFCOMMChannelID = 0
        service.getRFCOMMChannelID(&channelID)
        if channelID == 0 {
            Logger.connection.error("Could not find channel id")
            return false
        }
        
        var channel:IOBluetoothRFCOMMChannel? = IOBluetoothRFCOMMChannel()
//        TODO: crashed here
        let status = device.openRFCOMMChannelSync(&channel, withChannelID: channelID, delegate: self)
        
        if status == kIOReturnSuccess {
            Logger.connection.debug("Connected to \(device.name ?? "unknown device") on channel \(channelID)")
            self.rfcommChannel = channel
            return true
        } else {
//            self.attemptCloseRFCOMM()
            Logger.connection.error("Failed to connect channel id: \(channelID) with status: \(status)")
        }
        return false
    }
    
    
    func attemptCloseRFCOMM(retries: Int = 3, force:Bool = false) {
        guard let channel = self.rfcommChannel else {
            Logger.connection.error("Channel does not exist")
            return
        }
        if let device = channel.getDevice(){
            for attempt in 1...retries {
                if channel.isOpen() {
                    let status = device.closeConnection()
                    if !channel.isOpen() {
                        Logger.connection.debug("Connection closed successfully on attempt \(attempt)")
                        device.closeConnection()
                        break
                    } else {
                        Logger.connection.error("Attempt \(attempt) to close Connection failed: \(status)")
                        Thread.sleep(forTimeInterval: 1)
                    }
                }
            }
        }
    }

    
    
    func writeData(data: Data){
        guard let rfcommChannel = self.rfcommChannel, rfcommChannel.isOpen() else{
            Logger.connection.error("Could not write message! Channel does not exists or closed!")
            return
        }
        
        // Convert the size of the data to a 4-byte UInt32
        var dataSize = UInt32(data.count).bigEndian
        let sizeBufferPointer = withUnsafeMutablePointer(to: &dataSize) {
            return UnsafeMutableRawPointer($0)
        }
        // Write the size of the data first
        Logger.connection.debug("Current MTU: \(rfcommChannel.getMTU())")
        let mtu = rfcommChannel.getMTU()
        
        let sizeWriteResult = rfcommChannel.writeSync(sizeBufferPointer, length: UInt16(MemoryLayout.size(ofValue: dataSize)))
        if sizeWriteResult != kIOReturnSuccess {
            Logger.connection.error("Failed to write data size: \(String(describing: sizeWriteResult))")
            return
        }
        self.writeRawSegments(data: data, rfCommChannel: rfcommChannel, mtu: Int(mtu))
    }
    
    func writeRawSegments(data: Data, rfCommChannel: IOBluetoothRFCOMMChannel, mtu: Int){
        Logger.connection.debug("Segmenting data!")
        let dataSize = data.count
        Logger.connection.info("Segmented data size: \(dataSize)")
        let totalChunks = Int(ceil(Double(dataSize) / Double(mtu)))
        
        for cid in 0..<totalChunks {
            let start = cid * mtu
            let end = min(start + mtu, dataSize)
            let chunk = data.subdata(in: start..<end)
            writeRawData(data: chunk, rfCommChannel: rfCommChannel)
        }
    }
    
    func writeRawData(data: Data, rfCommChannel: IOBluetoothRFCOMMChannel) {
        // Write actual data
        let dataBufferPointer = UnsafeMutableRawPointer(mutating: (data as NSData).bytes)
        let dataWriteResult = rfCommChannel.writeSync(dataBufferPointer, length: UInt16(data.count))
//        let dataWriteResult  = rfCommChannel.writeAsync(dataBufferPointer, length: UInt16(data.count), refcon: nil)
        if dataWriteResult == kIOReturnSuccess {
            Logger.connection.debug("Data written successfully of size: \(data.count)")
            return
        } else {
            Logger.connection.error("Failed to write data: \(String(describing: dataWriteResult))")
        }
    }
}



extension BluetoothClient:IOBluetoothRFCOMMChannelDelegate{
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            Logger.connection.debug("RFCOMM Channel opened successfully.")
//            MediaRemoteHelper.getNowPlayingInfo()
            ConnectionViewModel.shared.update(connected: true)
            ConnectionViewModel.shared.update(deviceName: rfcommChannel.getDevice().nameOrAddress)
            Logger.connection.info("MTU: \(rfcommChannel.getMTU())")
        } else {
            Logger.connection.error("Failed to open RFCOMM Channel: \(error.description)")
            ConnectionViewModel.shared.update(connected: false)
        }
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Logger.connection.debug("RFCOMM Channel: closed: \(rfcommChannel.getID())")
        ConnectionViewModel.shared.update(connected: false)
        ConnectionViewModel.shared.update(deviceName: "Unknown")
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        Logger.connection.debug("RFCOMM Channel: received data")
        
        let data = Data(bytes: dataPointer, count: Int(dataLength))
        self.backgroundQueue.async { [weak self] in
            guard let self = self else { return }

            self.incomingDataBuffer.append(data)
            self.processDataBuffer()
        }
    }

    private func processDataBuffer() {
        if expectedDataLength == nil {
            // need at least 4 bytes to read the length header.
            guard incomingDataBuffer.count >= 4 else {
                return // Not enough data to read the length header yet.
            }

            // Extract the 4-byte header to determine message length.
            let sizeData = incomingDataBuffer.prefix(4)
            // Safely extract bytes without alignment issues
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
                
                // Clear buffer and reset state
                self.incomingDataBuffer.removeAll()
                self.expectedDataLength = nil
                return
            }
            
            Logger.connection.info("Expecting new message with length: \(length) bytes.")
            self.expectedDataLength = length
            incomingDataBuffer.removeFirst(4)
        }
        guard let expectedLength = expectedDataLength else {
            return
        }
        
        guard incomingDataBuffer.count >= expectedLength else {
            Logger.connection.debug("Waiting for more data: have \(self.incomingDataBuffer.count), need \(expectedLength)")
            return
        }

        let messageChunk = incomingDataBuffer.prefix(expectedLength)
        let completeMessageData = Data(messageChunk)
        
        Logger.connection.info("Complete message of size \(completeMessageData.count) reassembled.")
        self.backgroundQueue.async {
            AppRepository.shared.readData(data: completeMessageData)
        }

        incomingDataBuffer.removeFirst(expectedLength)
        expectedDataLength = nil

        // Process any remaining data in the buffer
        if !self.incomingDataBuffer.isEmpty {
            Logger.connection.debug("Processing remaining \(self.incomingDataBuffer.count) bytes in buffer.")
            self.processDataBuffer()
        }
    }
    
    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        if error == kIOReturnSuccess{
            Logger.connection.debug("RFCOMM Channel: data written successfully")
        }
        else{
            Logger.connection.error("RFCOMM Channel: failed to write message")
        }
    }
}


// 1. Define the target class that will handle the SDP query callback
class SDPQueryDelegate: NSObject {
    func sdpQueryComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        if status == kIOReturnSuccess {
            print("SDP query completed successfully for device: \(device.name ?? "Unknown Device")")
            // You can now check services or proceed with the RFCOMM channel
        } else {
            print("SDP query failed with status: \(status)")
            // Handle failure case
        }
    }
    
}

