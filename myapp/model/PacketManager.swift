//
//  PacketManager.swift
//  myapp
//
//  Created by Aakash Solanki on 28/04/24.
//

import Foundation
import AppKit
import ISSoundAdditions
import OSLog



class PacketManager{

    init(){}

    func readNotification(mesage: String){
        let data = mesage.split(separator: ":")
        if !data.isEmpty{
            print("data: \(data[0])")
            if(data[0] == "DESTROY"){
                AppRepository.shared.stop()
                MediaManager.shared.stop()
            }
            else if(data[0] == "REFRESH" || data[0] == "CONNECT"){
                MediaManager.shared.reset()
            }
            else if(data[0] == "CONNECTED"){
                print("Its a read request notification!!")
            }
        }
    }
    
    func readCommand(message: String){
        let data = message.split(separator: ":")
        if !data.isEmpty{
            let event = data[0]
            let commandPrefix = "shortcuts run BLEShortcut -i"
            if (event.contains("PLAY")){
                runShellCommand(command: "\(commandPrefix) 'PLAY'")
            }
            else if(event.contains("NEXT")){
                runShellCommand(command: "\(commandPrefix) 'NEXT'")
            }
            else if(event.contains("PREV")){
                runShellCommand(command: "\(commandPrefix) 'PREV'")
            }
            else if(event.contains("VFULL")){
                Sound.output.setVolume(1.0, autoMuteUnmute: true)
            }
            else if(event.contains("VMUTE")){
                Sound.output.isMuted = !Sound.output.isMuted
            }
            else if(event.contains("VINC")){
                Sound.output.increaseVolume(by: 0.0625)
            }
            else if(event.contains("VDEC")){
                Sound.output.decreaseVolume(by: 0.0625)
            }
            else if(event.contains("SEEKM")){
                if let doubleValue = Double(data[1]) {
                    MediaRemoteHelper.setElapsedTime(doubleValue)
                } else {
                    print("Invalid number format")
                }

            }
            else if(event.contains("SEEKV")){
                if let floatValue = Float(data[1]) {
                    Sound.output.setVolume(floatValue, autoMuteUnmute: true)
                } else {
                    print("Invalid number format")
                }
            }
        }
    }
        
}

