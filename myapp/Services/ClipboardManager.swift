//
//  ClipboardManager.swift
//  Passover
//
//  Created by Aakash Solanki on 24/08/24.
//


import Foundation
import AppKit
import os

class ClipboardManager {
    static let shared = ClipboardManager()
    private var pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var isAddingData: Bool = false
    private var timer:Timer? = nil
    
    var bluetoothClient: BluetoothL2capClient? = nil

    private init() {
        changeCount = pasteboard.changeCount
        startMonitoringClipboard()
    }
    
    deinit{
        timer?.invalidate()
        timer = nil
    }

    private func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        guard !isAddingData, pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        if let types = pasteboard.types {
            for type in types {
                if type == .png, let imageData = pasteboard.data(forType: .png) {
                    Logger.connection.info("Image data")
                    let base64String = imageData.base64EncodedString()
                    gotNewData(data: base64String)
                } else if type == .tiff, let imageData = pasteboard.data(forType: .tiff) {
                    Logger.connection.info("Tiff data")
                    let base64String = imageData.base64EncodedString()
                    gotNewData(data: base64String)
                } else if type == .string, let textData = pasteboard.string(forType: .string) {
                    Logger.connection.info("Text data")
                    gotNewData(data: textData)
                }
            }
        }
    }

    func addDataToClipboard(data: ClipBoard) {
        isAddingData = true
        pasteboard.clearContents()
        if(data.origin == "txt"){
            pasteboard.setString(data.text, forType: .string)
        }
        else if(data.origin == "img"){
            Logger.connection.info("Got image data")
//            pasteboard.setData(image.tiffRepresentation, forType: .tiff)
        }
        else{
            return
        }
        changeCount = pasteboard.changeCount
        isAddingData = false
    }

    
    private func gotNewData(data: Any) {
        if let base64String = data as? String {
            if let decodedData = Data(base64Encoded: base64String), let image = NSImage(data: decodedData) {
                if let pngData = convertToPNG(image: image) {
                    let pngBase64String = pngData.base64EncodedString()
                    Logger.connection.debug("New clipboard image (Base64 PNG): \(pngBase64String)")
                    self.publishData(text: pngBase64String, type: "img")
                } else {
                    Logger.connection.debug("New clipboard image (Original Base64): \(base64String)")
                    self.publishData(text: base64String, type: "img")
                }
            } else {
                let preview = base64String.count > 10 ? String(base64String.prefix(20)) : base64String
                Logger.connection.debug("New clipboard text: \(preview)")
                self.publishData(text: base64String, type: "txt")
            }
        }
    }

    private func convertToPNG(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    
    private func publishData(text: String, type: String){
        let clipData = BPacket.with{
            $0.type = MessageType.clipboard
            $0.clipboard = ClipBoard.with{
                $0.text = text
                $0.timestamp =  String(describing: NSDate().timeIntervalSince1970)
                $0.origin = type
            }
        }
        
        do {
            let serializedData = try clipData.serializedData()
//            bluetoothClient?.sendData(data: serializedData)
            bluetoothClient?.send(data: serializedData)
        }catch let error{
            Logger.connection.error("Failed to send packet due to \(error)")
        }
        
    }
}

