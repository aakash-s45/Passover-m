//
//  BluetoothClient.swift
//  myapp
//
//  Created by Aakash Solanki on 14/09/24.
//

import Foundation
import IOBluetooth
import CoreBluetooth
import os


class BluetoothClient: NSObject, CBCentralManagerDelegate{
    var isConnected: Bool = false
    var isStopped:Bool = false
    
    var centralManager: CBCentralManager?
    var hfDevice: IOBluetoothHandsFreeDevice?
    var backgroundQueue:DispatchQueue
    var rfcommChannel:IOBluetoothRFCOMMChannel?
    var inquiry:IOBluetoothDeviceInquiry?
    
    override init() {
        self.backgroundQueue = DispatchQueue(label: "app.passover.bg", qos: .background)
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: self.backgroundQueue)
        Logger.connection.debug("BluetoothClient init")
    }
    
    deinit{Logger.connection.debug("BluetoothClient deinit")}
    
    func start(){
        guard let hfd = self.hfDevice else{
            Logger.connection.warning("No Gateway proxy found to connect!")
            return
        }
        self.connect(to: hfd.device)
    }
    
    func stop(){
        self.stopInquiry()
        if ConnectionViewModel.shared.is_connected{
            self.attemptCloseRFCOMM(retries: 3)
        }
        else if HFDState.shared.is_connected{
            self.disconnect()
        }
        self.isStopped = true
    }
    
    func update(device: IOBluetoothDevice){
        self.hfDevice = IOBluetoothHandsFreeDevice(device: device, delegate: self)
    }
    
}

extension BluetoothClient{
    func connect(to device:IOBluetoothDevice){
        self.runSDPquery(to: device)
        if device.isHandsFreeAudioGateway{
            self.hfDevice = IOBluetoothHandsFreeDevice(device: device, delegate: self)
            self.hfDevice?.connect()
        }
        else{
            Logger.connection.error("Device do not support HandsFreeAudioGateway!")
        }
    }
    func disconnect(){
        guard let hfd = self.hfDevice else{
            Logger.connection.warning("No Gateway proxy found to disconnect!")
            return
        }
        if hfd.isConnected{
            hfd.disconnect()
            Logger.connection.warning("Disconnecting")
        }
        else{
            Logger.connection.warning("Not connected to Gateway!")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            ConnectionViewModel.shared.update(is_power: true)
            self.connecToSavedDevice()
        case .poweredOff:
            print("Bluetooth is powered off")
            ConnectionViewModel.shared.update(is_power: false)
            self.stop()
        case .resetting:
            print("Bluetooth is resetting")
            self.stop()
        case .unauthorized:
            print("Bluetooth is unauthorized")
            self.stop()
        case .unsupported:
            print("Bluetooth is unsupported on this device")
            self.stop()
        case .unknown:
            print("Bluetooth state is unknown")
            self.stop()
        @unknown default:
            self.stop()
            fatalError()
        }
    }
    
    func connecToSavedDevice(){
        let savedDevice = AppRepository.shared.getExistingDevice()
        if !savedDevice.isEmpty{
            ConnectionViewModel.shared.update(is_device: true)
            ConnectionViewModel.shared.update(savedDevice: savedDevice)
            Logger.connection.debug("Saved device address: \(savedDevice.description)")
//            let device = IOBluetoothDevice(addressString: "98-09-cf-a5-f2-ef")
            if let device = IOBluetoothDevice(addressString: savedDevice[0]){
                self.update(device: device)
                self.start()
            }
            else{
                Logger.connection.error("Couldn't conenct to saved device address: \(savedDevice.description)")
            }
        }
        else{
            self.startInquiry()
        }
    }
}
