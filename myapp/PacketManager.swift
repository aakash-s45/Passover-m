//
//  PacketManager.swift
//  myapp
//
//  Created by Aakash Solanki on 28/04/24.
//

import Foundation
import AppKit
import ISSoundAdditions


struct BPacket{
    var type: Character
    var seq: Int32
    var data: Data
    
    func toData() -> Data{
        var _data = Data()
        _data.append(type.asciiValue!)
        _data.append(contentsOf: withUnsafeBytes(of: seq.bigEndian, Array.init))
        _data.append(contentsOf: data)
        return _data
    }
}

class PacketManager{
    static let shared = PacketManager()
//    private let method = "reliable"
    private let method = "fast"
    
    private let bleState = BLEStateManager.shared
    private var chunkSize: Int = 507
    private var chunks:[BPacket] = []
    
    private init(){}
    
//    split data into segments
    func segmentData(data: Data){
        print("Segmenting data.....")
        chunks.removeAll()
        let dataSize = data.count
        print("Current data size: \(dataSize)")
        let totalChunks = Int(ceil(Double(dataSize) / Double(chunkSize)))
        
        for cid in 0..<totalChunks{
            let start = cid * chunkSize
            let end = min(start + chunkSize, dataSize)
            let chunk = data.subdata(in: start..<end)
            self.chunks.append(BPacket(type: "G", seq: Int32(cid), data: chunk))
        }
        
        print(self.chunks.count)
        print("Total segments done: \(self.chunks.count)")
//        TODO: uncomment the line below to send artwork packets
        self.sendPacket(packet: BPacket(type: "I", seq: Int32(self.chunks.count), data: method.data(using: .utf8)!))
    }
    
    
    func generatePacket(type:Character = "G", seq:Int32 = 0, data:Data = Data())->BPacket{
        return BPacket(type:type, seq: seq, data: data)
    }
    
    func nextPacket(seq: Int32)->BPacket?{
        if seq-1 < chunks.count{
            return chunks[Int(seq)-1]
        }
        return nil
    }
    

    
    func sendPacket(packet: BPacket){
        if(bleState.acceptWrite){
            let _packet = packet.toData()
            bleState.currentPeripheral?.writeValue(_packet, for: bleState.outputCharacteristic!, type: .withResponse)
        }
    }
    
    func readNotification(mesage: String){
        let data = mesage.split(separator: ":")
        if !data.isEmpty{
            if(data[0]=="ACK"){
                if(method == "reliable"){
                    guard let seq = Int(data[1]) else {
                        print("Can not convert seq:\(data[1]) to string")
                        return
                    }
                    if (seq >= 0 && seq<chunks.count){
                        print("Sending packet for seq: \(seq) / \(chunks.count)")
                        self.sendPacket(packet: self.chunks[seq])
                    }
                }
                else if(method == "fast"){
                    print("Sending packet for all seq")
                    for chunk in chunks {
                        self.sendPacket(packet: chunk)
                    }
                }
                
            }
            else if(data[0] == "READ"){
                print("Its a read request notification!!")
                if(bleState.readCharacteristic != nil){
                    bleState.currentPeripheral?.readValue(for: bleState.readCharacteristic!)
                }
            }
            else if(data[0] == "CONNECTED"){
                print("Its a read request notification!!")
                if(bleState.readCharacteristic != nil){
                    bleState.currentPeripheral?.readValue(for: bleState.readCharacteristic!)
                }
            }
        }
    }
    
    func readRemoteMessage(message: String){
        print("It's a read request data: \(message)")
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
//                runShellCommand(command: "\(commandPrefix) 'VOLFULL'")
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
                print("Data[1]: \(data[1])")
                guard let seekValue = Int(data[1]) else {
                    return
                }
                print("Data[1]: \(seekValue)")
//                runShellCommand(command: "\(commandPrefix) 'SEEKM_\(String(describing: Int()))'")
            }
            else if(event.contains("SEEKV")){
                if let doubleValue = Double(data[1]) {
                    let seekValue = Int(doubleValue)
                    runShellCommand(command: "\(commandPrefix) 'SEEKV_\(seekValue)'")
                } else {
                    print("Invalid number format")
                }


            }
        }
    }
        
}




func runShellCommand(command: String) {
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]
    
    process.launch()
    process.waitUntilExit()
}


func convertTiffToPng(imageData: Data) -> Data? {
    
    guard let image = NSImage(data: imageData) else {
        print("Failed to create NSImage from TIFF data.")
        return nil
    }
    
    guard let tiffRepresentation = image.tiffRepresentation else {
        print("Failed to get TIFF representation from NSImage.")
        return nil
    }
    
    guard let tiffBitmap = NSBitmapImageRep(data: tiffRepresentation) else {
        print("Failed to create NSBitmapImageRep from TIFF data.")
        return nil
    }
    
    var compressionRatio = 0.25
    if (imageData.count < 40*512){
        compressionRatio = 1.0
    }

    
    let properties: [NSBitmapImageRep.PropertyKey: Any] = [
        NSBitmapImageRep.PropertyKey.compressionFactor: compressionRatio
        ]
    
    guard let pngData = tiffBitmap.representation(using: .jpeg, properties: properties) else {
        print("Failed to convert TIFF image to PNG data.")
        return nil
    }
    
    return pngData
}
