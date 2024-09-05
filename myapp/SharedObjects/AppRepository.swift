//
//  AppRepository.swift
//  myapp
//
//  Created by Aakash Solanki on 31/08/24.
//

import Foundation
import IOBluetooth
import os

class AppRepository{
    static let shared = AppRepository()
    
    private var bluetoothManager:BluetoothManager?
    private var rfcommClient:RFCommClient?
    private var clipboardHandler: ClipboardHandler?
    private var packetManager: PacketManager?
    private var userPreference: UserPreferences?
    
    init(){}
    
    func start(){
        rfcommClient = RFCommClient()
        packetManager = PacketManager()
        clipboardHandler = ClipboardHandler()
        userPreference = UserPreferences()
        bluetoothManager = BluetoothManager(rfcommClient: rfcommClient, userPreference: userPreference)
    }
    
    
    func stop(){
        bluetoothManager = nil
        rfcommClient = nil
        clipboardHandler = nil
        packetManager = nil
    }
    
    func stopInquiry(){
        ConnectionViewModel.shared.update(is_scanning: false)
        rfcommClient?.stopInquiry()
    }
    
    func clearDevice(){
        userPreference?.clear()
    }
    
    func select(device: IOBluetoothDevice){
        bluetoothManager?.select(device: device)
    }
    
    func readData(data:Data){
        do{
            let packet = try BPacket(serializedData: data)
            if packet.type == MessageType.remote{
                let remoteData = packet.remoteData
                if remoteData.event == "CMD"{
                    packetManager?.readCommand(message: remoteData.extraData)
                }
                else if remoteData.event == "TASK"{
                    packetManager?.readNotification(mesage: remoteData.extraData)
                }
            }
        }catch let error{
            Logger.connection.error("Failed to read data using \(data) with error \(error)")
        }
    }
    
    func writeData(data: BPacket){
        if ConnectionViewModel.shared.is_connected{
            if let client = rfcommClient{
                do {
                    let serialized_data = try data.serializedData()
                    let status = client.writeData(data: serialized_data)
                    if !status{
                        Logger.connection.error("Failed to write data")
                    }
                }catch let error{
                    Logger.connection.error("Failed to send packet due to \(error)")
                }

            }
        }
        else{
            Logger.connection.warning("Couldn't write message!")
        }
    }
}
