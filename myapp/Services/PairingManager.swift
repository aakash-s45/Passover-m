import Foundation
import SwiftUI
import CryptoKit
import CoreImage.CIFilterBuiltins
import OSLog

class PairingManager: ObservableObject{
    
    @Published var deviceId: String = ""
    @Published var qrCode: Image?
    @Published var isKeySaved: Bool = false
    
    private(set) var currentEncryptionKey: SymmetricKey?
    private var kDeviceId = "passover.deviceId"
    private var kIsKeySaved = "passover.isKeySaved"
    
    init() {
        getOrGenerateDeviceId()
        checkAndHandleEncryptionKey()
        updateQRCode()
    }
    
    deinit{
        Logger.ui.info("PairingManager is stopping")
    }
    
    private func getOrGenerateDeviceId(){
        if let storedId = UserDefaults.standard.string(forKey: kDeviceId){
            deviceId = storedId
            Logger.ui.info("Loaded deviceId from UserDefaults")
        } else{
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: kDeviceId)
            Logger.ui.info("Generated and saved new Device ID")
        }
    }
    
    private func checkAndHandleEncryptionKey(){
        isKeySaved = UserDefaults.standard.bool(forKey: kIsKeySaved)
        if isKeySaved {
            Logger.ui.info("Encryption key is already saved")
            currentEncryptionKey = nil
        }
        else {
            generateTempEncryptionKey()
        }
    }
    
    private func generateTempEncryptionKey(){
        currentEncryptionKey = KeyStore.getNewKey()
        Logger.ui.info("Generated new encryption key")
    }
    
    func saveEncryptionKey(){
        guard let keyToSave = currentEncryptionKey else {
            Logger.ui.error("No temporary key available to save")
            return
        }
        
        do{
            try KeyStore.saveKey(key: keyToSave, for: deviceId)
        }catch{
            Logger.ui.error("Failed to save the generated encryption key due to error: \(error)")
            return
        }
        
        UserDefaults.standard.set(true, forKey: kIsKeySaved)
        isKeySaved = true
        currentEncryptionKey = nil
        updateQRCode()
        Logger.ui.info("Encryption key saved!")
    }
    
    func forgetPermanentKey(){
        UserDefaults.standard.set(false, forKey: kIsKeySaved)
        isKeySaved = false
        generateTempEncryptionKey()
        updateQRCode()
        Logger.ui.info("Encryption key removed!")
    }
    
    private func updateQRCode(){
        guard !isKeySaved, let key = currentEncryptionKey else {
            self.qrCode = nil
            Logger.ui.warning("No encryption key to generate QR code or New QR not needed")
            return
        }
        
        let keyData = key.withUnsafeBytes{ Data($0) }
        let keyBase64 = keyData.base64EncodedString()
        let qrPayload = Message.with{
            $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
            $0.qrPayload = QRPayload.with{
                $0.deviceID = deviceId
                $0.key = keyBase64
            }
        }

        do{
            let qrDataBase64 = try qrPayload.serializedData().base64EncodedData()
            if let ciImage = generateQRCode(from: qrDataBase64){
                self.qrCode = convertCIImageToImage(ciImage: ciImage)
            }
            else{
                Logger.ui.error("Faild to generate QR code")
                self.qrCode = nil
            }
        }catch{
            Logger.ui.error("Faild to create QR code")
            self.qrCode = nil
        }
    }
    
    private func generateQRCode(from inputData: Data) -> CIImage?{
        let qrCodeGenerator = CIFilter.qrCodeGenerator()
        qrCodeGenerator.message = inputData
        qrCodeGenerator.correctionLevel = "H"
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        return qrCodeGenerator.outputImage?.transformed(by: scale)
    }
    
    private func convertCIImageToImage(ciImage: CIImage) -> Image?{
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            Logger.ui.error("Failed to convert CIImage to CGImage")
            return nil
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
        return Image(nsImage: nsImage)
    }
}
