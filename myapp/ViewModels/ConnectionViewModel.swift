//
//  ConnectionViewModel.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import Foundation
import IOBluetooth

class ConnectionViewModel: ObservableObject{
    static let shared = ConnectionViewModel()
    
    @Published var device:IOBluetoothDevice? = nil
    @Published var is_connected = false
    @Published var is_hf_connected = false
    @Published var is_device_saved = false
    @Published var is_powered_on = false
    @Published var is_scanning = false
    @Published var scanResult = [IOBluetoothDevice]()
    @Published var savedDevice:[(String)] = []
    
    private var connectionTimer: Timer?
    
    private init(){
        AppRepository.shared.start()
    }
    
    func update(is_scanning: Bool = false){
        DispatchQueue.main.async {
            self.is_scanning = is_scanning
        }
    }
    
    func update(is_power: Bool = false){
        DispatchQueue.main.async {
            self.is_powered_on = is_power
        }
    }
    
    func update(is_device: Bool = false){
        DispatchQueue.main.async {
            self.is_device_saved = is_device
        }
    }
    
    func update(savedDevice: [(String)]){
        DispatchQueue.main.async {
            self.savedDevice = savedDevice
        }
    }
    
    func update(connected: Bool = false){
        DispatchQueue.main.async {
            self.is_connected = connected
        }
    }
    
    func update(hf_connected: Bool = false){
        DispatchQueue.main.async {
            self.is_hf_connected = hf_connected
        }
    }
    
    func update(device: IOBluetoothDevice){
        DispatchQueue.main.async {
            self.device = device
        }
    }
    
    
    func addScanResult(device:IOBluetoothDevice){
        DispatchQueue.main.async {
            self.scanResult.append(device)
        }
    }
    
    func stopScan(){
        DispatchQueue.main.async {
            self.scanResult.removeAll()
        }
    }
    
    private func startConnection() {
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.attemptConnection()
        }
    }
    
    private func attemptConnection() {
        if is_powered_on && !is_connected{
            AppRepository.shared.start()
        }
    }
    
    func stopConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    func connect(to device:IOBluetoothDevice){
        AppRepository.shared.select(device: device)
    }
}
