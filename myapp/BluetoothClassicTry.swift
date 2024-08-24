//
//  BluetoothClassicTry.swift
//  myapp
//
//  Created by Aakash Solanki on 26/05/24.
//

import Foundation

import IOBluetooth
import AVFAudio

class BluetoothManager: NSObject, IOBluetoothDeviceInquiryDelegate {
    var inquiry: IOBluetoothDeviceInquiry?

    func startInquiry() {
        print("start inquiry")
        inquiry = IOBluetoothDeviceInquiry(delegate: self)
        inquiry?.start()
    }

    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry, error: IOReturn, aborted: Bool) {
        if error == kIOReturnSuccess {
            print("Inquiry completed successfully.")
        } else {
            print("Inquiry failed with error: \(error)")
        }
    }

    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry, device: IOBluetoothDevice) {
        print("Found device: \(device.name ?? "unknown")")
        if let name = device.name, name == "OnePlus 7" {
            inquiry?.stop()
            device.openConnection()
            let service = IOBluetoothHandsFreeAudioGateway(device: device, delegate: self)
        
        }
    }
    

    
    
}


