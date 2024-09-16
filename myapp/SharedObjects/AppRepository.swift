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
    var bluetoothClient: BluetoothClient?
    private var clipboardHandler: ClipboardHandler?
    private var packetManager: PacketManager?
    private var userPreference: UserPreferences?
    
    init(){Logger.connection.debug("repository init")}
    
    deinit{Logger.connection.debug("repository deinit")}
    
    func start(){
        Logger.connection.debug("Starting the app from repository")
        packetManager = PacketManager()
        clipboardHandler = ClipboardHandler()
        userPreference = UserPreferences()
        bluetoothClient = BluetoothClient()
    }
    
    func stop(){
        bluetoothClient?.stop()
        clipboardHandler = nil
        packetManager = nil
    }
    
    func scan(){
        bluetoothClient?.startInquiry()
    }
    
    func stopInquiry(){
        bluetoothClient?.stopInquiry()
    }
    
    func clearDevice(){
        userPreference?.clear()
    }
    
    func select(device: IOBluetoothDevice){
        userPreference?.update(identifier: device.addressString, name: device.nameOrAddress)
        bluetoothClient?.update(device: device)
        bluetoothClient?.start()
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
            if let client = bluetoothClient{
                do {
                    let serialized_data = try data.serializedData()
                    client.writeData(data: serialized_data)
                }catch let error{
                    Logger.connection.error("Failed to send packet due to \(error)")
                }

            }
        }
        else{
            Logger.connection.warning("Couldn't write message!")
        }
    }
    
    func forgetDevice(){
        self.stop()
        userPreference?.clear()
        ConnectionViewModel.shared.update(connected: false)
        ConnectionViewModel.shared.update(is_device: false)
    }

    func getExistingDevice()->[(String)]{
        return userPreference?.get() ?? []
    }
}
