////
////  BLEViewModel.swift
////  myapp
////
////  Created by Aakash Solanki on 23/06/23.
////
//


import Foundation

import CoreBluetooth

class BLEViewModel: ObservableObject {
    static let shared = BLEViewModel()

    @Published var isSwitchedOn = false
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var currentDevice: CBPeripheral? = nil
    @Published var scanResults: [CBPeripheral: NSNumber] = [:]

    private var accessKey: String? = nil
    var savedidentifier: UUID? = nil
    private var bleClient: NewBleClient? = nil

    private init() {
        let keyManager = AccessKeyManager.shared
        keyManager.rotateKey()
        self.accessKey = keyManager.getCurrentKey()

        if let identifier = UserDefaults.standard.object(forKey: BLEUtils.saveIdentifierKey) {
            self.savedidentifier = UUID(uuidString: identifier as! String)
        }
        self.bleClient = NewBleClient()
    }

    func updateScanStatus(status: Bool = false) {
        DispatchQueue.main.async {
            self.isScanning = status
        }
    }

    func updateConnectionStatus(status: Bool = false) {
        DispatchQueue.main.async {
            self.isConnected = status
        }
    }

    func updateSwitchStatus(status: Bool = false) {
        DispatchQueue.main.async {
            self.isSwitchedOn = status
        }
    }

    func updateCurrentDevice(device: CBPeripheral) {
        DispatchQueue.main.async {
            self.currentDevice = device
        }
    }

    func updateScanResult(peripheral: CBPeripheral, rssi: NSNumber, override: Bool = false) {
        DispatchQueue.main.async {
            if override {
                self.scanResults.removeAll()
            }
            self.scanResults[peripheral] = rssi
        }
    }

    func updateIdentifier(identifier: String, delete: Bool = false) {
        UserDefaults.standard.removeObject(forKey: BLEUtils.saveIdentifierKey)
        if !delete {
            UserDefaults.standard.setValue(identifier, forKey: BLEUtils.saveIdentifierKey)
        } else {
            UserDefaults.standard.removeObject(forKey: BLEUtils.saveIdentifierKey)
        }
    }

    func clearIdentifiers() {
        UserDefaults.standard.removeObject(forKey: BLEUtils.saveIdentifierKey)
    }
    
    func connectToDevice(peripheral: CBPeripheral){
        bleClient?.connect(toPeripheral: peripheral)
        self.updateIdentifier(identifier: peripheral.identifier.uuidString)
        DispatchQueue.main.async {
            self.currentDevice = peripheral
            self.isScanning = false
        }
    }
    
    
    func disconnect(){
        if self.currentDevice != nil{
            bleClient?.disconnectDevice(fromPeripheral: currentDevice!)
            self.updateIdentifier(identifier: currentDevice!.identifier.uuidString)
        }        
    }
    
    func startScan(){
        bleClient?.startScan()
    }
    func stopScan(){
        bleClient?.stopScan()
    }
}
