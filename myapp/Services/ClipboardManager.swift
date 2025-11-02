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
    private var pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var isAddingData: Bool = false
    private var timer:Timer? = nil
    
    var onClipboardUpdate: ((ClipboardMessage) -> Void)?

    init() {
        changeCount = pasteboard.changeCount
        startMonitoringClipboard()
        Logger.connection.info("Clipboard manager started!")
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
                    updateClientClipboard(data: base64String)
                } else if type == .tiff, let imageData = pasteboard.data(forType: .tiff) {
                    Logger.connection.info("Tiff data")
                    let base64String = imageData.base64EncodedString()
                    updateClientClipboard(data: base64String)
                } else if type == .string, let textData = pasteboard.string(forType: .string) {
                    Logger.connection.info("Text data")
                    updateClientClipboard(data: textData)
                }
            }
        }
    }

    func addDataToClipboard(data: ClipboardMessage) {
        isAddingData = true
        pasteboard.clearContents()
        
        if(data.type == .txt){
            pasteboard.setString(data.content, forType: .string)
        }
        else if(data.type == .img){
            Logger.connection.info("Got image data")
//            pasteboard.setData(image.tiffRepresentation, forType: .tiff)
        }
        else{
            return
        }
        changeCount = pasteboard.changeCount
        isAddingData = false
    }

    
    private func updateClientClipboard(data: Any) {
        if let base64String = data as? String {
            if let decodedData = Data(base64Encoded: base64String), let image = NSImage(data: decodedData) {
                if let pngData = convertToPNG(image: image) {
                    let pngBase64String = pngData.base64EncodedString()
                    Logger.connection.debug("New clipboard image (Base64 PNG)")
                    self.publishData(text: pngBase64String, type: "img")
                } else {
                    Logger.connection.debug("New clipboard image (Original Base64)")
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
        var contentType = ClipboardMessage.ClipboardContentType.txt
        if(type == "img"){
            contentType = ClipboardMessage.ClipboardContentType.img
        }

        let clipboardData = ClipboardMessage.with{
            $0.content = text
            $0.type = contentType
        }
        
        onClipboardUpdate?(clipboardData)
    }
}

