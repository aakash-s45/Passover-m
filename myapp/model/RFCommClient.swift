import Foundation
import IOBluetooth
import OSLog
import Combine

// All bluetooth services in android
// ["cBluetoothServer", "Handsfree Gateway", "SMS/MMS", "AV Remote Control Target", "OBEX Phonebook Access Server", "Advanced Audio", "Headset Gateway"]

class RFCommClient: NSObject {
    private var inquiry: IOBluetoothDeviceInquiry?
    private let serverName: String = "cBluetoothServer"
    let serviceNames: [String] = ["cBluetoothServer", "Handsfree Gateway"]
    private var serviceChannelMapping: [String: BluetoothRFCOMMChannelID] = [:]
    private var rfCommChannel: IOBluetoothRFCOMMChannel?

    private var phoneBookChannel: IOBluetoothRFCOMMChannel?
    private var currentDevice: IOBluetoothDevice?
    private lazy var inquiryDelegate: IOBluetoothDeviceInquiryDelegate = InquiryDelegate()
    private lazy var rfcommDelegate: IOBluetoothRFCOMMChannelDelegate = RFCommDelegate()
    
    // Handfree Device
    private let HFGName: String = "Handsfree Gateway"
    private var hfDevice: IOBluetoothHandsFreeDevice? = nil
    private var handsfreeChannel: IOBluetoothRFCOMMChannel?
    private lazy var hfRFcommDelegate: IOBluetoothRFCOMMChannelDelegate = RFCommDelegate2()
    private lazy var hfDeviceDelegate: IOBluetoothHandsFreeDeviceDelegate = HFDeviceDelegate()
    
    // AVRCP
    private let AVRCPName: String = "AV Remote Control Target"
    private var avrcpChannel: IOBluetoothL2CAPChannel?
    private var avrcpPSM: BluetoothL2CAPPSM = 0
    private lazy var l2capDelegate: IOBluetoothL2CAPChannelDelegate = L2CAPDelegate()
    
    
    override init() {
        super.init()
        for serviceName in serviceNames {
            serviceChannelMapping[serviceName] = 0
        }
    }
    
    deinit{
        self.stop()
    }
    
    func isConnected()->Bool{
        if currentDevice?.isConnected() ?? false && hfDevice?.isConnected ?? false{
            return true
        }
        return false
    }
    
    func connect(to device: IOBluetoothDevice) {
        Logger.connection.debug("Attempting to connect to device: \(device.nameOrAddress)")
        let status = device.openConnection()
        if status != kIOReturnSuccess {
            Logger.connection.error("Could not connect to device: \(device.nameOrAddress)")
        }
        
        for service in device.services {
            let serviceRecord = service as! IOBluetoothSDPServiceRecord
            let name = serviceRecord.getServiceName()
            if name == nil {
                continue
            }
            
            if self.serviceChannelMapping.keys.contains(name!) {
                serviceRecord.getRFCOMMChannelID(&self.serviceChannelMapping[name!])
            } else if name == AVRCPName {
                serviceRecord.getL2CAPPSM(&avrcpPSM)
            }
        }
        inquiry?.stop()
        print("Service Channel Mapping: \(serviceChannelMapping.debugDescription)")
        
        for (serviceName, chID) in self.serviceChannelMapping {
            if chID > 0 {
                switch serviceName {
                case serverName:
                    _ = connect(to: device, with: chID)
                case HFGName:
                    connectHandsfree(to: device, with: chID)
//                case AVRCPName:
//                    // Handle AVRCP connection if needed
//                    break
                default:
                    print("Unimplemented service: \(serviceName)")
                }
            }
        }
    }
    
    func connectAVRCP(to device: IOBluetoothDevice, with psm: BluetoothL2CAPPSM) {
        var l2capChannel: IOBluetoothL2CAPChannel?
        let status = device.openL2CAPChannelSync(&l2capChannel, withPSM: psm, delegate: l2capDelegate)
        if status == kIOReturnSuccess {
            Logger.connection.debug("AVRCP Connected to \(device.name ?? "unknown device") with psm \(psm)")
            self.avrcpChannel = l2capChannel
        } else {
            self.avrcpChannel = nil
            print("AVRCP Failed to connect psm id: \(psm) with status: \(status)")
        }
    }
    
    func connectHandsfree(to device: IOBluetoothDevice, with channelID: BluetoothRFCOMMChannelID) {
        var rfcommChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelSync(&rfcommChannel, withChannelID: channelID, delegate: hfRFcommDelegate)
        if status == kIOReturnSuccess {
            Logger.connection.debug("HF Connected to \(device.name ?? "unknown device") on channel \(channelID)")
            self.hfDevice = IOBluetoothHandsFreeDevice(device: device, delegate: hfDeviceDelegate)
            self.hfDevice?.connect()
            self.handsfreeChannel = rfcommChannel
        } else {
            self.handsfreeChannel = nil
            print("HF Failed to connect channel id: \(channelID) with status: \(status)")
        }
    }
    
    func connect(to device: IOBluetoothDevice, with channelID: BluetoothRFCOMMChannelID) -> Bool {
        var rfcommChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelSync(&rfcommChannel, withChannelID: channelID, delegate: rfcommDelegate)
        
        if status == kIOReturnSuccess {
            Logger.connection.debug("Connected to \(device.name ?? "unknown device") on channel \(channelID)")
            self.rfCommChannel = rfcommChannel
            MediaRemoteHelper.getNowPlayingInfo()
            return true
        } else {
            self.rfCommChannel = nil
            print("Failed to connect channel id: \(channelID) with status: \(status)")
            return false
        }
    }
    
    func writeData(data: Data) -> Bool {
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
        
        // Write actual data
        return writeRawSegments(data: data, rfCommChannel: rfCommChannel, mtu: Int(mtu))
    }
    
    func writeRawData(data: Data, rfCommChannel: IOBluetoothRFCOMMChannel) -> Bool {
        // Write actual data
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
    
    func writeRawSegments(data: Data, rfCommChannel: IOBluetoothRFCOMMChannel, mtu: Int) -> Bool {
        Logger.connection.debug("Segmenting data.....")
        let dataSize = data.count
        Logger.connection.info("Segmented data size: \(dataSize)")
        let totalChunks = Int(ceil(Double(dataSize) / Double(mtu)))
        
        for cid in 0..<totalChunks {
            let start = cid * mtu
            let end = min(start + mtu, dataSize)
            let chunk = data.subdata(in: start..<end)
            let status = writeRawData(data: chunk, rfCommChannel: rfCommChannel)
            if !status {
                return false
            }
        }
        return true
    }
    
    func startInquiry() {
        Logger.connection.debug("Starting Inquiry")
        inquiry = IOBluetoothDeviceInquiry(delegate: inquiryDelegate)
        inquiry?.start()
    }
    
    func stopInquiry() {
        inquiry?.stop()
        inquiry = nil
        Logger.connection.debug("Inquiry stopped")
    }
    
    func stop(){
        self.stopInquiry()
        
        // reset things
        serviceChannelMapping = [:]
        avrcpPSM = 0
        
        // close connection
        hfDevice?.disconnect()
        hfDevice?.disconnectSCO()
        hfDevice = nil
        
        currentDevice?.closeConnection()
        currentDevice = nil
        
        
        // Remove channels
        handsfreeChannel = nil
        avrcpChannel = nil
        rfCommChannel = nil
        phoneBookChannel = nil
    }
    
}

