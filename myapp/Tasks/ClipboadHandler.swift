//
//  Clipboard.swift
//  myapp
//
//  Created by Aakash Solanki on 24/08/24.
//

import Foundation
import AppKit
import os

class ClipboardHandler {
    private var pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var isAddingData: Bool = false
    private var timer:Timer? = nil

    init() {
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
                    let base64String = imageData.base64EncodedString()
                    gotNewData(data: base64String)
                } else if type == .tiff, let imageData = pasteboard.data(forType: .tiff) {
                    let base64String = imageData.base64EncodedString()
                    gotNewData(data: base64String)
                } else if type == .string, let textData = pasteboard.string(forType: .string) {
                    gotNewData(data: textData)
                }
            }
        }
    }

    func addDataToClipboard(data: Any) {
        isAddingData = true
        pasteboard.clearContents()

        if let imageData = data as? Data, let image = NSImage(data: imageData) {
            pasteboard.setData(image.tiffRepresentation, forType: .tiff)
        } else if let textData = data as? String {
            pasteboard.setString(textData, forType: .string)
        }

        changeCount = pasteboard.changeCount
        isAddingData = false
    }

    
    func gotNewData(data: Any) {
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
                Logger.connection.debug("New clipboard text: \(base64String)")
                self.publishData(text: base64String, type: "txt")
            }
        }
    }

    func convertToPNG(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    
    func publishData(text: String, type: String){
        let clipData = BPacket.with{
            $0.type = MessageType.clipboard
            $0.clipboard = ClipBoard.with{
                $0.text = text
                $0.timestamp =  String(describing: NSDate().timeIntervalSince1970)
                $0.origin = type
            }
        }
        AppRepository.shared.writeData(data: clipData)
    }
}

