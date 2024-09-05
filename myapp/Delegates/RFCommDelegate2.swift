import os
import IOBluetooth

class RFCommDelegate2: IOBluetoothRFCOMMChannelDelegate{
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        if error == kIOReturnSuccess {
            Logger.connection.debug("RFCOMM Channel 2 opened successfully.")
            ConnectionViewModel.shared.update(hf_connected: true)
            ConnectionViewModel.shared.update(device: rfcommChannel.getDevice())
        } else {
            Logger.connection.error("Failed to open RFCOMM Channel 2: \(error)")
            ConnectionViewModel.shared.update(hf_connected: false)
        }
    }
    
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Logger.connection.debug("RFCOMM Channel 2: closed: \(rfcommChannel.getID())")
        ConnectionViewModel.shared.update(hf_connected: false)
    }
    
    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        Logger.connection.debug("RFCOMM Channel 2: received data")
        
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


