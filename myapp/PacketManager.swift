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
    static let shared = PacketManager()
//    private let method = "reliable"
    private let method = "fast"
    
    private var chunkSize: Int = 980
    private var chunks:[BPacket] = []
    
    private init(){}
    
    func sendImageData(data: Data){
        let dataSize = data.count
        let imagePacket = BPacket.with {
            $0.type = MessageType.graphics
            $0.graphic = Graphic.with{
                $0.seq = 0
                $0.data = data
            }
        }
        self.send(packet: imagePacket)
    }
    
    func sendClipboardData(text: String, type: String){
        let clipData = BPacket.with{
            $0.type = MessageType.clipboard
            $0.clipboard = ClipBoard.with{
                $0.text = text
                $0.timestamp =  String(describing: NSDate().timeIntervalSince1970)
                $0.origin = type
            }
        }
        self.send(packet: clipData)
    }
    
//    split data into segments
    func segmentData(data: Data){
        chunkSize = data.count
        Logger.connection.debug("Segmenting data.....")
        chunks.removeAll()
        let dataSize = data.count
        Logger.connection.info("Segmented data size: \(dataSize)")
        let totalChunks = Int(ceil(Double(dataSize) / Double(chunkSize)))
        
        
        for cid in 0..<totalChunks{
            let start = cid * chunkSize
            let end = min(start + chunkSize, dataSize)
            let chunk = data.subdata(in: start..<end)
            
            let imagePacket = BPacket.with {
                $0.type = MessageType.graphics
                $0.graphic = Graphic.with{
                    $0.seq = Int32(cid)
                    $0.data = chunk
                }
            }
            self.chunks.append(imagePacket)
        }
        

        print("Total segments done: \(self.chunks.count)")
//        TODO: uncomment the line below to send artwork packets
        sendInitPacket()
    }
    
    
    func sendInitPacket(){
        let _init = BPacket.with {
            $0.type = MessageType.metadata
            $0.metadata = MetaData.with{
                $0.type = method
                $0.size = Int32(self.chunks.count)
            }
        }
        self.send(packet: _init)
    }
    
    
    func nextPacket(seq: Int32)->BPacket?{
        if seq-1 < chunks.count{
            return chunks[Int(seq)-1]
        }
        return nil
    }
    
    
    func send(packet: BPacket, forceWrite:Bool = false){
        do {
            let _data = try packet.serializedData()
//            Logger.connection.info("Size of chunk: \(_data.count)")
            BluetoothViewModel.shared.connectionState.writeData(data: _data)
        }catch let error{
            Logger.connection.error("Failed to send packet due to \(error)")
        }
    }
    

    
    func readNotification(mesage: String){
        let data = mesage.split(separator: ":")
        if !data.isEmpty{
            print("data: \(data[0])")
            if(data[0]=="ACK"){
                if(method == "reliable"){
                    guard let seq = Int(data[1]) else {
                        print("Can not convert seq:\(data[1]) to string")
                        return
                    }
                    if (seq >= 0 && seq<chunks.count){
                        print("Sending packet for seq: \(seq) / \(chunks.count)")
                        self.send(packet: self.chunks[seq])
                    }
                }
                else if(method == "fast"){
                    print("Sending packet for all seq")
                    for chunk in chunks {
                        self.send(packet: chunk)
//                        break
                    }
                }
                
            }
            else if(data[0] == "DESTROY"){
//                TODO: update this method
                BluetoothViewModel.shared.disconnect()
//                TODO: restart all
            }
            else if(data[0] == "REFRESH" || data[0] == "CONNECT"){
                MediaManager.shared.cleaMediaState()
                MediaRemoteHelper.getNowPlayingInfo()
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
                
//                guard let seekValue = Int(data[2]) else {
//                    print("can't seek: \(message)")
//                    return
//                }
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


func applyBlur(to imageData: Data, radius: CGFloat) -> Data? {
    guard let inputImage = CIImage(data: imageData) else { return nil }
    
    let filter = CIFilter(name: "CIGaussianBlur")
    filter?.setValue(inputImage, forKey: kCIInputImageKey)
    filter?.setValue(radius, forKey: kCIInputRadiusKey)
    
    guard let outputImage = filter?.outputImage else { return nil }
    
    let context = CIContext()
    guard let cgImage = context.createCGImage(outputImage, from: inputImage.extent) else { return nil }
    
    let blurredImage = NSImage(cgImage: cgImage, size: NSSize(width: inputImage.extent.width, height: inputImage.extent.height))
    guard let tiffData = blurredImage.tiffRepresentation else { return nil }
    
    return tiffData
}

func convertTiffToPng(imageData: Data) -> Data? {
    

    var imageTosend = imageData
    var compressionRatio = 0.25
    if (imageData.count < 40*512){
        imageTosend = applyBlur(to: imageData, radius: 1.5) ?? imageData
        compressionRatio = 1.0
    }
    
    guard let image = NSImage(data: imageTosend) else {
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
    
    

    
    let properties: [NSBitmapImageRep.PropertyKey: Any] = [
        NSBitmapImageRep.PropertyKey.compressionFactor: compressionRatio
        ]
    
    guard let pngData = tiffBitmap.representation(using: .jpeg, properties: properties) else {
        print("Failed to convert TIFF image to PNG data.")
        return nil
    }
    
    return pngData
}
