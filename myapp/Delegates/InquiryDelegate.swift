import os
import Combine
import IOBluetooth

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
