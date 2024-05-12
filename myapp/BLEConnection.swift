//
//  BleConnectionManager.swift
//  myapp
//
//  Created by Aakash Solanki on 07/04/24.
//

import Foundation
import CoreBluetooth


class BLEStateManager{
    static let shared = BLEStateManager()
    
    var isConnected: Bool = false
    var isScanning: Bool = false
    var scanResults = [String]()
    
    
    
    
    var acceptWrite: Bool = false
    var currentPeripheral: CBPeripheral? = nil
    var outputCharacteristic: CBCharacteristic? = nil
    var readCharacteristic: CBCharacteristic? = nil

    private init(){}
    
    func change(isConnected: Bool){
        self.isConnected = isConnected
        if(isConnected == false){
            self.acceptWrite = false
            self.acceptWrite = false
            self.currentPeripheral = nil
            self.outputCharacteristic = nil
            self.readCharacteristic = nil
        }
    }
    
    func change(isScanning: Bool){
        self.isScanning = isScanning
    }
    
    func change(currentPeripheral: CBPeripheral?, characteristic: CBCharacteristic){
        if(!isConnected){
            return
        }
        if let peripheral = currentPeripheral{
            self.acceptWrite = true
            self.currentPeripheral = peripheral
            self.outputCharacteristic = characteristic
            PacketManager.shared.sendPacket(packet: AccessKeyManager.shared.getKeyData(), forceWrite: true)
            MediaRemoteHelper.getNowPlayingInfo()
//            MediaManager.shared.publishData(overrideData: true)
//            PacketManager.shared.sendInitPacket()
        }
        else{
            self.acceptWrite = false
            self.currentPeripheral = nil
            self.outputCharacteristic = nil
            self.readCharacteristic = nil
        }
    }
}



