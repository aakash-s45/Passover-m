//
//  Utilities.swift
//  myapp
//
//  Created by Aakash Solanki on 31/08/24.
//

import Foundation
import AppKit
import SwiftUI

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
    
    print(tiffBitmap.debugDescription)
    guard let newTiffBitmap = cropToSquare(imageRep: tiffBitmap) else{
        print("Failed to crop NSBitmapImageRep from TIFF data.")
        return nil
    }
    print(newTiffBitmap.debugDescription)
    

    
    let properties: [NSBitmapImageRep.PropertyKey: Any] = [
        NSBitmapImageRep.PropertyKey.compressionFactor: compressionRatio
        ]
    
    
    
    guard let pngData = newTiffBitmap.representation(using: .jpeg, properties: properties) else {
        print("Failed to convert TIFF image to PNG data.")
        return nil
    }
    
    return pngData
}


func cropToSquare(imageRep: NSBitmapImageRep) -> NSBitmapImageRep? {
    let originalWidth = imageRep.pixelsWide
    let originalHeight = imageRep.pixelsHigh
    let squareSize = min(originalWidth, originalHeight)

    // Calculate the cropping rectangle to center the square
    let xOffset = (originalWidth - squareSize) / 2
    let yOffset = (originalHeight - squareSize) / 2

    let croppingRect = NSRect(x: xOffset, y: yOffset, width: squareSize, height: squareSize)
    
    guard let cgImage = imageRep.cgImage else {
        return nil
    }

    // Create a new CGImage by cropping the original CGImage
    guard let croppedCgImage = cgImage.cropping(to: croppingRect) else {
        return nil
    }
    
    // Create a new NSBitmapImageRep from the cropped CGImage
    return NSBitmapImageRep(cgImage: croppedCgImage)
}


func intToData(_ value: Int) -> Data {
    var int = value
    return Data(bytes: &int, count: MemoryLayout<Int>.size)
}

func getBatteryString(charge: Int)->String{
    switch charge{
    case 0: return "battery.0percent"
    case 1: return "battery.25percent"
    case 2: return "battery.25percent"
    case 3: return "battery.50percent"
    case 4: return "battery.75percent"
    case 5: return "battery.100percent"
    default: return "battery.100percent"
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}
