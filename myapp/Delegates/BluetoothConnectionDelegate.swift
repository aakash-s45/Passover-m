//
//  BluetoothConnectionDelegate.swift
//  myapp
//
//  Created by Aakash Solanki on 23/06/24.
//

import Foundation
import CoreBluetooth
import IOBluetooth
import os


class BluetoothManager: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var rfcommClient: RFCommClient?
    private var userPreference: UserPreferences?

    init(rfcommClient:RFCommClient?, userPreference: UserPreferences?) {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.rfcommClient = rfcommClient
        self.userPreference = userPreference
    }
    
    deinit{
        self.stopRFCommClient()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            ConnectionViewModel.shared.update(is_power: true)
            self.connect()
        case .poweredOff:
            print("Bluetooth is powered off")
            ConnectionViewModel.shared.update(is_power: false)
            self.stopRFCommClient()
        case .resetting:
            print("Bluetooth is resetting")
            self.stopRFCommClient()
        case .unauthorized:
            print("Bluetooth is unauthorized")
            self.stopRFCommClient()
        case .unsupported:
            print("Bluetooth is unsupported on this device")
            self.stopRFCommClient()
        case .unknown:
            print("Bluetooth state is unknown")
            self.stopRFCommClient()
        @unknown default:
            fatalError()
        }
    }
    
    func stopRFCommClient(){
        rfcommClient?.stopInquiry()
        rfcommClient?.stop()
        rfcommClient = nil
        ConnectionViewModel.shared.update(connected: false)
    }
    
    func connect(){
        let savedDevice = getExistingDevice()
        if !savedDevice.isEmpty{
            ConnectionViewModel.shared.update(is_device: true)
            ConnectionViewModel.shared.update(savedDevice: savedDevice)
            Logger.connection.debug("Saved device address: \(savedDevice.description)")
//            let device = IOBluetoothDevice(addressString: "98-09-cf-a5-f2-ef")
            if let device = IOBluetoothDevice(addressString: savedDevice[0]){
                rfcommClient?.connect(to: device)
            }
            else{
                Logger.connection.error("Couldn't conenct to saved device address: \(savedDevice.description)")
            }
        }
        else{
            rfcommClient?.startInquiry()
        }
    }
    
    func select(device: IOBluetoothDevice){
        rfcommClient?.connect(to: device)
        Logger.connection.debug("Selecting device with id:\(device.addressString), name:\(device.nameOrAddress)")
        userPreference?.update(identifier: device.addressString, name: device.nameOrAddress)
    }
        
    func forgetDevice(){
        self.stopRFCommClient()
        userPreference?.clear()
        ConnectionViewModel.shared.update(connected: false)
        ConnectionViewModel.shared.update(is_device: false)
    }
    
    func getExistingDevice()->[(String)]{
        return userPreference?.get() ?? []
    }
    
    func isConnected()->Bool{
        if let connected = rfcommClient?.isConnected(){
            return connected
        }
        return false
    }
}
