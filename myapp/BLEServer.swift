//
//  BLEServer.swift
//  myapp
//
//  Created by Aakash Solanki on 23/06/23.
//

import Foundation
import CoreBluetooth

class BLEPeripheral:NSObject,ObservableObject,CBPeripheralManagerDelegate{
    
    @Published var isSwitchedOn = false
    @Published var msg:String = ""
    var isServiceAdded = false
    
    var peripheralManager: CBPeripheralManager!
    let characteristic1:CBMutableCharacteristic
    let characteristic2:CBMutableCharacteristic
    let service:CBMutableService
    let peripheralQueue:DispatchQueue
    let descriptor1:CBMutableDescriptor
    let descriptor2:CBMutableDescriptor
    

    override init(){
        
        self.descriptor1 = CBMutableDescriptor(type: BLEUtils.descriptor1, value: BLEUtils.desData1)
        self.characteristic1 = CBMutableCharacteristic(type: BLEUtils.characteristicID, properties: [.write], value: nil, permissions: [.writeable])
        self.characteristic1.descriptors = [descriptor1]
        
        self.descriptor2 = CBMutableDescriptor(type: BLEUtils.descriptor1, value: BLEUtils.desData2)
        self.characteristic2 = CBMutableCharacteristic(type: BLEUtils.characteristicID2, properties: [.write], value: nil, permissions: [.writeable])
        self.characteristic2.descriptors = [descriptor2]
        
        self.service = CBMutableService(type: BLEUtils.serviceID, primary: true)
        self.service.characteristics = [characteristic1, characteristic2]

        self.peripheralQueue = DispatchQueue(label: "Peripheral Queue")
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: peripheralQueue)
        print("init finished 1")
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("BLE peripheral state: \(peripheral.state)")
        if peripheral.state == .poweredOn{
            print("Peripheral State: ON")
            isSwitchedOn = true
            
            peripheralManager.add(self.service)
            
        }
        else{
            print("Peripheral State: OFF")
            isSwitchedOn = false
            peripheralManager.removeAllServices()
            if(peripheral.isAdvertising){
                peripheralManager.stopAdvertising()
            }
            
        }
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error{
            print("Add service failed: \(error.localizedDescription)")
            return
        }else{
            print("Service \(service.uuid) added!")
            let advertisingData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [self.service.uuid], // Include service UUID in advertising data
                CBAdvertisementDataLocalNameKey: "YourDeviceName" // Set local name for the peripheral
            ]

            peripheralManager.startAdvertising(advertisingData)
            print("is advertising: \(peripheralManager.isAdvertising)")
        }
    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error{
            print("Advertisement failed with error: \(error.localizedDescription)")
            return
        }else{
            print("Advertisement Started")
            print("Hello this")
            print("is advertising: \(peripheralManager.isAdvertising)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("Write request recieved")
        print(requests)
        for request in requests{
            peripheralManager.respond(to: request, withResult: .success)
            guard let data = request.value else{
                return
            }
            let message = String(decoding: data, as: UTF8.self)
            msg = message
            print(message)
        }
        
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("Read recieved \(request.description)")
        peripheralManager.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
    }
    
    func checkAdvertis(){
        print("is advertising:: \(self.peripheralManager.isAdvertising)")
    }
    
    
}
