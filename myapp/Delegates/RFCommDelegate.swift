import os
import IOBluetooth

class RFCommDelegate: IOBluetoothRFCOMMChannelDelegate{
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            Logger.connection.debug("RFCOMM Channel opened successfully.")
            ConnectionViewModel.shared.update(connected: true)
            ConnectionViewModel.shared.update(device: rfcommChannel.getDevice())
        } else {
            Logger.connection.error("Failed to open RFCOMM Channel: \(error)")
            ConnectionViewModel.shared.update(connected: false)
        }
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Logger.connection.debug("RFCOMM Channel: closed: \(rfcommChannel.getID())")
        ConnectionViewModel.shared.update(connected: false)
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        Logger.connection.debug("RFCOMM Channel: received data")
        
        let data = Data(bytes: dataPointer, count: Int(dataLength))
        AppRepository.shared.readData(data: data)
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
