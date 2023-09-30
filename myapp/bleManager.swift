//
//  bleManager.swift
//  myapp
//
//  Created by Aakash Solanki on 21/03/23.
//

import Foundation
import CoreBluetooth

class BLEServer: NSObject,ObservableObject, CBPeripheralManagerDelegate{
    var manager: CBPeripheralManager!
    
    @Published var isSwitchedOn = false
    @Published var msg:String = ""
    @Published var isConnected = false
    
    let characteristicID:CBUUID
    let characteristicID2:CBUUID
    let serviceID:CBUUID
    
    
    let characteristic:CBMutableCharacteristic
    let characteristic2:CBMutableCharacteristic
    let service: CBMutableService
    let peripheralQueue: DispatchQueue
    
    
    override init() {
        self.serviceID = BLEUtils.serviceID
        self.characteristicID = BLEUtils.characteristicID
        self.characteristicID2 = BLEUtils.characteristicID2
    
        self.characteristic = CBMutableCharacteristic(type: characteristicID,
                                                      properties: [.write, .read],
                                                      value: nil,
                                                      permissions: [.readable, .writeable])
        self.characteristic2 = CBMutableCharacteristic(type: characteristicID2,
                                                       properties: [.read,.write,],
                                                       value: nil,
                                                       permissions: [.readable,.writeable])
        self.service = CBMutableService(type: serviceID, primary: true)
        self.service.characteristics = [characteristic,characteristic2]
        self.peripheralQueue = DispatchQueue(label: "Peripheral Queue")
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: peripheralQueue)
        
    }
//    Bluetooth state callback
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn{
            print("peripheral.state is .poweredOn !")
            isSwitchedOn = true
            manager?.add(self.service)
        }
        else{
            print("Bluetooth off")
            isSwitchedOn = false
        }
    }
//    Advertisement callback
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Advetisement failed: \(error.localizedDescription)")
            return
        }
        print("Advertisement Started!")
    }
//    Add service callback
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Add service failed: \(error.localizedDescription)")
            return
        }
        else{
            print("Add service succeeded")
            let advertisingName = "My BLE App"
            let advertisementData:[String:Any] = [CBAdvertisementDataLocalNameKey: advertisingName, CBAdvertisementDataServiceUUIDsKey: [service.uuid]]
            manager?.startAdvertising(advertisementData)
        }
        
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print(requests.description)
        guard let data = requests[0].value else { return }
        
        // Decode/Parse the data here
        let message = String(decoding: data, as: UTF8.self)
        msg = message
        print(message)
    }
    
    
}
