//
//  bleScan.swift
//  myapp
//
//  Created by Aakash Solanki on 21/06/23.
//

import Foundation
import CoreBluetooth

class BLEClient: NSObject,ObservableObject,CBCentralManagerDelegate,CBPeripheralDelegate{

    var centralManager: CBCentralManager!
    
    let serviceID: CBUUID
    @Published var isSwitchedOn = false
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var isCharFound = false
    @Published var scanResults:[UUID:CBPeripheral] = [:]
    @Published var currentPeripheral:CBPeripheral? = nil
    var timer: Timer?
    var gattCharacteristic:CBCharacteristic? = nil
    let centralQueue:DispatchQueue
    
    override init() {
        self.serviceID = BLEUtils.serviceID
        self.centralQueue = DispatchQueue(label: "Central Queue")
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn{
            print("central.state is .poweredOn !")
            isSwitchedOn = true
        }
        else{
            print("Bluetooth off")
            isSwitchedOn = false
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Found device: ")
        print(peripheral.name ?? "Unknown")
        scanResults[peripheral.identifier] = peripheral
    }
    func startScan(){
        print("Start Scanning")
        isScanning = true
        centralManager.scanForPeripherals(withServices: [self.serviceID])
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false){t in
            self.stopScan()
            print("Stopped scanning after 10 seconds")
        }
    }
    func stopScan(){
        print("Stop Scanning")
        isScanning = false
        centralManager.stopScan()
    }
    func disconnnectDevice(){
        if(currentPeripheral != nil){
            centralManager.cancelPeripheralConnection(currentPeripheral!)
        }
        
    }
    func connectToDevice(peripheral:CBPeripheral){
        print("Connecting to peripheral")
        centralManager.connect(peripheral)
    }
    func disconnect(peripheral:CBPeripheral){
        print("Disconnecting peripheral")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to Peripheral")
        currentPeripheral = peripheral
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices([BLEUtils.serviceID])
        
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("failed to Connect")
        currentPeripheral = nil
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral with error: \(String(describing: error?.localizedDescription))")
        
        currentPeripheral = nil
        isConnected = false
        isCharFound = false
    }
    
    
//    ------------ peripheral delegates -------------
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Service discovered")
        var services:[CBService]? = peripheral.services
        services?.forEach{service in
            print(service.uuid)
            if(service.uuid == BLEUtils.serviceID){
                peripheral.discoverCharacteristics([BLEUtils.characteristicID], for: service)
            }
        }
        
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Characteristics found for service: \(service.uuid)")
        var characteristics:[CBCharacteristic]? = service.characteristics
        characteristics?.forEach{ch in
            print("Characteristic uuid: \(ch.uuid)")
            if(ch.uuid==BLEUtils.characteristicID){
                gattCharacteristic = ch
                isCharFound = true
                sendMessage(message: "Heeeelo from ble app")
            }
        }
    }
    
    func sendMessage(message:String){
        currentPeripheral?.writeValue(message.data(using: .utf8)!, for: gattCharacteristic!, type: .withResponse)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Write characteristic Success ✅")
    }
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Peripheral service changed")
        print(invalidatedServices.description)
    }
    
    
}

