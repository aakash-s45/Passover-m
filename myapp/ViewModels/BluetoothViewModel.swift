//import Foundation
//
//import CoreBluetooth
//import IOBluetooth
//import Combine
//
//class BluetoothViewModel: ObservableObject {
//    static let shared = BluetoothViewModel()
//    
//    @Published var isSwitchedOn = false
//    @Published var isScanning = false
//    @Published var isConnected = false
//    @Published var deviceName = ""
//
//    @Published var currentDevice: IOBluetoothDevice? = nil
//    @Published var scanResults: [IOBluetoothDevice: NSNumber] = [:]
//    
//    var savedidentifier: String? = nil
//    var devcieControl:DeviceControl? = nil
//    let scale = 120.0
//    var connectionState:ConnectionState = ConnectionState()
//    var clipboard:ClipboardHandler?
//    
//
//    private init() {
//        if let identifier = UserDefaults.standard.object(forKey: BLEUtils.saveIdentifierKey) {
//            self.savedidentifier = (identifier as! String)
//        }
//        DispatchQueue.main.async { self.startClient() }
//    }
//    
//    
//    
//    func startClient(){
//        connectionState.start()
//        clipboard = ClipboardHandler()
//    }
//
//    func updateScanStatus(status: Bool = false) {
//        DispatchQueue.main.async {
//            self.isScanning = status
//        }
//    }
//
//    func updateConnectionStatus(status: Bool = false) {
//        DispatchQueue.main.async {
//            self.isConnected = status
//        }
//    }
//
//    func updateSwitchStatus(status: Bool = false) {
//        DispatchQueue.main.async {
//            self.isSwitchedOn = status
//        }
//    }
//
//    func updateCurrentDevice(device: IOBluetoothDevice) {
//        DispatchQueue.main.async {
//            self.currentDevice = device
//            if device.name != nil{
//                self.deviceName = device.nameOrAddress!
//            }
//            else{
//                self.deviceName = "Bluetooth Device"
//            }
//            self.devcieControl = DeviceControl.shared
//            
//        }
//    }
//
//    func updateScanResult(device: IOBluetoothDevice, rssi: NSNumber, override: Bool = false) {
//        DispatchQueue.main.async {
//            if override {
//                self.scanResults.removeAll()
//            }
//            self.scanResults[device] = 0
//        }
//    }
//
//    func updateIdentifier(identifier: String, delete: Bool = false) {
//        UserDefaults.standard.removeObject(forKey: BLEUtils.saveIdentifierKey)
//        if !delete {
//            UserDefaults.standard.setValue(identifier, forKey: BLEUtils.saveIdentifierKey)
//        } else {
//            UserDefaults.standard.removeObject(forKey: BLEUtils.saveIdentifierKey)
//        }
//    }
//
//    func clearIdentifiers() {
//        UserDefaults.standard.removeObject(forKey: BLEUtils.saveIdentifierKey)
//        self.devcieControl = nil
//    }
//    
//    func connect(device: IOBluetoothDevice){
////        ConnectionState.shared.connect(to: "98-09-cf-a5-f2-ef")
//        connectionState.connect(to: device.addressString)
//        self.updateIdentifier(identifier: device.addressString)
//        DispatchQueue.main.async {
//            self.currentDevice = device
//            self.isScanning = false
//        }
//    }
//    
//    
//    func disconnect(){
//        if self.currentDevice != nil{
//            connectionState.disconnect()
//            self.updateIdentifier(identifier: currentDevice!.addressString)
//        }
//        self.devcieControl = nil
//    }
//    
//    func startScan(){
//        _ = connectionState.triggerDiscovery()
//    }
//    func stopScan(){
//        connectionState.stopDiscovery()
//    }
//}
