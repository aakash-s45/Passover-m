//
//  RFCommClient.swift
//  myapp
//
//  Created by Aakash Solanki on 23/06/24.
//

import Foundation
import IOBluetooth
import OSLog

// All bluetooth servicses in android
//["cBluetoothServer", "Handsfree Gateway", "SMS/MMS", "AV Remote Control Target" , "OBEX Phonebook Access Server", "Advanced Audio", "Headset Gateway"]


class RFCommClient:NSObject{
    private var inquiry: IOBluetoothDeviceInquiry?
    private let serverName: String = "cBluetoothServer"
    let serviceNames: [String] = ["cBluetoothServer", "Handsfree Gateway"]
    private var serviceChannelMapping: [String: BluetoothRFCOMMChannelID] = [:]
    private var rfCommChannel: IOBluetoothRFCOMMChannel?

    private var phoneBookChannel: IOBluetoothRFCOMMChannel?
    private var currentDevice: IOBluetoothDevice?
    private lazy var inquiryDelegate:IOBluetoothDeviceInquiryDelegate = InquiryDelegate()
    private lazy var rfcommDelegate:IOBluetoothRFCOMMChannelDelegate = RFCommDelegate()

//    Handfree Device
    private let HFGName: String = "Handsfree Gateway"
    private var hfDevice:IOBluetoothHandsFreeDevice? = nil
    private var handsfreeChannel: IOBluetoothRFCOMMChannel?
    private lazy var hfRFcommDelegate:IOBluetoothRFCOMMChannelDelegate = RFCommDelegate2()
    private lazy var hfDeviceDelegate:IOBluetoothHandsFreeDeviceDelegate = HFDeviceDelegate()
    
    
//    AVRCP
    private let AVRCPName: String = "AV Remote Control Target"
    private var avrcpChannel: IOBluetoothL2CAPChannel?
    private var avrcpPSM: BluetoothL2CAPPSM = 0
    private lazy var l2capDelegate:IOBluetoothL2CAPChannelDelegate = L2CAPDelegate()
    
    override init() {
        for serviceName in serviceNames {
            serviceChannelMapping[serviceName] = 0
        }
    }
    
    func connect(to device:IOBluetoothDevice){
        Logger.connection.debug("Attempting to connect to device: \(device.nameOrAddress)")
        let status = device.openConnection()
        if status != kIOReturnSuccess{
            Logger.connection.error("Could not connect to device: \(device.nameOrAddress)")
        }
        
        for service in device.services{
            let serviceRecord = service as! IOBluetoothSDPServiceRecord
//          Logger.connection.debug("Found services: \(serviceRecord.description)")
            let name = serviceRecord.getServiceName()
            if name == nil{
                continue
            }

            if self.serviceChannelMapping.keys.contains(name!) {
                serviceRecord.getRFCOMMChannelID(&self.serviceChannelMapping[name!])
            }
            else if name == AVRCPName{
                serviceRecord.getL2CAPPSM(&avrcpPSM)
            }
        }
        inquiry?.stop()
        print("Service Channel Mapping: \(serviceChannelMapping.debugDescription)")
        
        for (serviceName, chID) in self.serviceChannelMapping{
            if chID > 0{
//                Logger.connection.debug("Service: \(serviceName), channel ID: \(chID)")
                switch serviceName{
                case serverName:
                    print(serviceName)
                    _ = connect(to:device, with: chID)
                case HFGName:
                    print(serviceName)
                    connectHandsfree(to: device, with: chID)
                case AVRCPName:
                    print("avrcp")
 
                default:
                    print("unimplemnted service: \(serviceName)")
                }
            }
//            if(avrcpPSM==0){
//                print("couldn't find: \(serviceName)")
//            }
//            else{
//                print(serviceName)
////                connectAVRCP(to: device, with: avrcpPSM)
//            }
        }
        
    }
    
    func connectAVRCP(to device: IOBluetoothDevice, with psm: BluetoothL2CAPPSM){
        var l2capChannel: IOBluetoothL2CAPChannel?
        let status = device.openL2CAPChannelSync(&l2capChannel, withPSM: psm, delegate: l2capDelegate)
        if status == kIOReturnSuccess{
            Logger.connection.debug("AVRCP Connected to \(device.name ?? "unknown device") with psm \(psm)")
            self.avrcpChannel = l2capChannel
//            let command: [UInt8] = [
//                    0x00, // Transaction ID
//                    0x00, // Packet Type
//                    0x00, 0x19, // Length
//                    0x10, 0x00, 0x00, // PDU ID and Packet Type
//                    0x00, 0x01, // Length
//                    0x00, // Number of attributes
//                    0x00, 0x00, 0x00, 0x00, // Media Attribute ID (Title)
//                    0x00, 0x00, 0x00, 0x01, // Media Attribute ID (Artist)
//                    0x00, 0x00, 0x00, 0x02, // Media Attribute ID (Album)
//                    0x00, 0x00, 0x00, 0x03  // Media Attribute ID (Genre)
//                ]
//            var commandData = Data(command)
//            l2capChannel?.writeSync(&commandData, length: UInt16(commandData.count))
        }else{
            self.avrcpChannel = nil
            print("AVRCP Failed to connect psm id: \(psm) with status: \(status)")
        }
        
    }
    
    func connectHandsfree(to device: IOBluetoothDevice, with channelID: BluetoothRFCOMMChannelID){
        var rfcommChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelSync(&rfcommChannel, withChannelID: channelID, delegate: hfRFcommDelegate)
        if status == kIOReturnSuccess{
            Logger.connection.debug("HF Connected to \(device.name ?? "unknown device") on channel \(channelID)")
            self.hfDevice = IOBluetoothHandsFreeDevice(device: device, delegate: hfDeviceDelegate)
            self.hfDevice?.connect()
            self.handsfreeChannel = rfcommChannel
        }else{
            self.handsfreeChannel = nil
            print("HF Failed to connect channel id: \(channelID) with status: \(status)")
        }
    }
    
    
    
    func connect(to device: IOBluetoothDevice, with channelID: BluetoothRFCOMMChannelID)->Bool{
        var rfcommChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelSync(&rfcommChannel, withChannelID: channelID, delegate: rfcommDelegate)
        
        if status == kIOReturnSuccess{
            Logger.connection.debug("Connected to \(device.name ?? "unknown device") on channel \(channelID)")
            self.rfCommChannel = rfcommChannel
            MediaRemoteHelper.getNowPlayingInfo()
            print("device.isHandsFreeAudioGateway: \(device.isHandsFreeAudioGateway)")
            print("device.isHandsFreeDevice: \(device.isHandsFreeDevice)")
            return true
        }else{
            self.rfCommChannel = nil
            print("Failed to connect channel id: \(channelID) with status: \(status)")
            return false
        }
    }
    
    
    
    
    func writeData(data:Data)->Bool{
        guard let rfCommChannel = rfCommChannel, rfCommChannel.isOpen() else {
                return false
        }
        // Convert the size of the data to a 4-byte UInt32
        var dataSize = UInt32(data.count).bigEndian
        let sizeBufferPointer = withUnsafeMutablePointer(to: &dataSize) {
                return UnsafeMutableRawPointer($0)
        }
        
        // Write the size of the data first
        print("Current MTU: \(rfCommChannel.getMTU())")
        let mtu = rfCommChannel.getMTU()
        
        let sizeWriteResult = rfCommChannel.writeSync(sizeBufferPointer, length: UInt16(MemoryLayout.size(ofValue: dataSize)))
        if sizeWriteResult != kIOReturnSuccess {
            print("Failed to write data size: \(String(describing: sizeWriteResult))")
            return false
        }
        
        // write actual data
//        return writeRawData(data: data, rfCommChannel: rfCommChannel)
        return writeRawSegments(data: data, rfCommChannel: rfCommChannel, mtu: Int(mtu))
    }
    
    func writeRawData(data:Data, rfCommChannel:IOBluetoothRFCOMMChannel)->Bool{
        // write actual data
        let dataBufferPointer = UnsafeMutableRawPointer(mutating: (data as NSData).bytes)
        let dataWriteResult = rfCommChannel.writeSync(dataBufferPointer, length: UInt16(data.count))
        if dataWriteResult == kIOReturnSuccess {
            print("Data written successfully of size: \(data.count)")
            return true
        } else {
            print("Failed to write data: \(String(describing: dataWriteResult))")
            return false
        }
    }
    
    func writeRawSegments(data: Data, rfCommChannel:IOBluetoothRFCOMMChannel, mtu:Int)->Bool{
        Logger.connection.debug("Segmenting data.....")
        let dataSize = data.count
        Logger.connection.info("Segmented data size: \(dataSize)")
        let totalChunks = Int(ceil(Double(dataSize) / Double(mtu)))
        
        
        for cid in 0..<totalChunks{
            let start = cid * mtu
            let end = min(start + mtu, dataSize)
            let chunk = data.subdata(in: start..<end)
            let status = writeRawData(data: chunk, rfCommChannel: rfCommChannel)
            if !status{
                return false
            }
        }
        return true
    }
    
    func stop(){
        self.stopInquiry()
        rfCommChannel?.close()
        self.currentDevice?.closeConnection()
    }
    
    func startInquiry(){
        inquiry = IOBluetoothDeviceInquiry(delegate: inquiryDelegate)
        let status = inquiry?.start()
        if status == kIOReturnSuccess{
            Logger.connection.debug("inquiry start successfully")
        }
        else{
            inquiry = nil
            Logger.connection.error("inquiry failed to start with error code: \(String(describing: status))")
        }
    }
    
    func stopInquiry(){
        inquiry?.stop()
        inquiry = nil
    }
    
}


class InquiryDelegate: NSObject, IOBluetoothDeviceInquiryDelegate{
    
    func deviceInquiryStarted(_ sender: IOBluetoothDeviceInquiry!) {
        Logger.connection.debug("Device inquiry: started")
    }
    
    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        Logger.connection.debug("Device inquiry: completed")
    }
    
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        Logger.connection.debug("Device inquiry: found device: \(device.debugDescription)")
        
        BluetoothViewModel.shared.connectionState.updateScanResult(device: device)
        
    }
    
    func deviceInquiryUpdatingDeviceNamesStarted(_ sender: IOBluetoothDeviceInquiry!, devicesRemaining: UInt32) {
        Logger.connection.debug("Device inquiry: updating device names started")
    }
    
    func deviceInquiryDeviceNameUpdated(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32) {
        Logger.connection.debug("Device inquiry: device name udpated")
    }
}

class RFCommDelegate: IOBluetoothRFCOMMChannelDelegate{
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            Logger.connection.debug("RFCOMM Channel opened successfully.")
            BluetoothViewModel.shared.connectionState.isConnected = true
        } else {
            Logger.connection.error("Failed to open RFCOMM Channel: \(error)")
            BluetoothViewModel.shared.connectionState.isConnected = false
        }
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Logger.connection.debug("RFCOMM Channel: closed: \(rfcommChannel.getID())")
        BluetoothViewModel.shared.connectionState.isConnected = false
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        Logger.connection.debug("RFCOMM Channel: received data")
        
        let data = Data(bytes: dataPointer, count: Int(dataLength))
        BluetoothViewModel.shared.connectionState.readData(data: data)
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


class RFCommDelegate2: IOBluetoothRFCOMMChannelDelegate{
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            Logger.connection.debug("RFCOMM Channel 2 opened successfully.")
//            ConnectionState.shared.isConnected = true
        } else {
            Logger.connection.error("Failed to open RFCOMM Channel 2: \(error)")
//            ConnectionState.shared.isConnected = false
        }
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Logger.connection.debug("RFCOMM Channel 2: closed: \(rfcommChannel.getID())")
//        ConnectionState.shared.isConnected = false
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        Logger.connection.debug("RFCOMM Channel 2: received data")
        
//        let data = Data(bytes: dataPointer, count: Int(dataLength))
//        ConnectionState.shared.readData(data: data)
    }
    
    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        if error == kIOReturnSuccess{
            Logger.connection.debug("RFCOMM Channel 2: data written successfully")
        }
        else{
            Logger.connection.error("RFCOMM Channel 2: failed to write message")
        }
    }
    
}

