//
//  ConnectionState.swift
//  myapp
//
//  Created by Aakash Solanki on 23/06/24.
//

import Foundation
import IOBluetooth
import OSLog
import SwiftProtobuf


class ConnectionState{
//    static let shared = ConnectionState()
    
    var deviceName: String?
    var deviceAddress: String?
    var device: IOBluetoothDevice?
    
    var isBluetoothEnabled:Bool = false
    var isConnected:Bool = false
    var isScanning:Bool = false
    
    private var rfcommClient:RFCommClient?
    private var timer:Timer?
    private var scanResult:[String:IOBluetoothDevice] = [:]
    
        
    func start(){
        Logger.connection.info("Starting RFCOMM client")
        rfcommClient = RFCommClient()
        self.connect(to: "98-09-cf-a5-f2-ef")
    }
    
    func updateServerName(to name: String){
        
    }
    
    func connect(to deviceAddress: String){
        device = IOBluetoothDevice(addressString: deviceAddress)
        rfcommClient?.connect(to: device!)
    }
    
    func disconnect(){
        rfcommClient?.stop()
    }
    
    func triggerDiscovery() -> Bool{
        Logger.connection.debug("Starting discovery")
        timer?.invalidate()
        scanResult.removeAll()
        if !isBluetoothEnabled{
            Logger.connection.error("Bluetooth not enabled")
            return false
        }
        self.isScanning = true
        self.rfcommClient?.startInquiry()
        timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false){t in
            self.stopDiscovery()
        }
        return true
    }
    
    func stopDiscovery(){
        self.isScanning = false
        self.rfcommClient?.stopInquiry()
        Logger.connection.debug("Stopped discovery")
    }
    
    func updateScanResult(device: IOBluetoothDevice){
        scanResult[device.addressString] = device
    }
    
    func readData(data:Data){
        do{
            let packet = try BPacket(serializedData: data)
            if packet.type == MessageType.remote{
                let remoteData = packet.remoteData
                let packetManager = PacketManager.shared
                if remoteData.event == "CMD"{
                    packetManager.readCommand(message: remoteData.extraData)
                }
                else if remoteData.event == "TASK"{
                    packetManager.readNotification(mesage: remoteData.extraData)
                }
            }
        }catch let error{
            Logger.connection.error("Failed to read data using \(data) with error \(error)")
        }
    }
    
    func writeData(data: Data){
        if rfcommClient != nil{
            let status = rfcommClient!.writeData(data: data)
            if !status{
                Logger.connection.error("Failed to write data")
            }
        }
    }
    
    func intToData(_ value: Int) -> Data {
        var int = value
        return Data(bytes: &int, count: MemoryLayout<Int>.size)
    }
    
    
}
