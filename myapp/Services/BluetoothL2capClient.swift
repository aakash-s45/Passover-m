//
//  BluetoothL2capClient.swift
//  Passover
//
//  Created by Aakash Solanki on 22/07/25.
//


import Foundation
import CoreBluetooth
import Combine

class BluetoothL2capClient: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, StreamDelegate {
    static let shared = BluetoothL2capClient()
    
    @Published var status = "Disconnected"
    @Published var receivedMessage = ""

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var l2capChannel: CBL2CAPChannel?
    
    private var psm: CBL2CAPPSM?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            status = "Ready to Scan"
        } else {
            status = "Bluetooth is not available"
        }
    }

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        status = "Scanning..."
        centralManager.scanForPeripherals(withServices: [L2CAP_SERVICE_UUID], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Extract PSM from advertisement data
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let psmData = serviceData[L2CAP_SERVICE_UUID] {
            
            // PSM is a 16-bit unsigned integer (UInt16) sent in little-endian format
            self.psm = psmData.withUnsafeBytes { $0.load(as: UInt16.self) }
            status = "Found device: \(peripheral.name ?? "Unknown"), PSM: \(self.psm!)"
            print("Found device with PSM: \(self.psm!)")
            
            centralManager.stopScan()
            targetPeripheral = peripheral
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Connected. Opening L2CAP Channel..."
        peripheral.delegate = self
        
        // Open L2CAP channel using the discovered PSM
        if let psm = self.psm {
            peripheral.openL2CAPChannel(psm)
        } else {
            status = "Error: PSM not found."
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let error = error {
            status = "L2CAP channel error: \(error.localizedDescription)"
            return
        }
        guard let channel = channel else {
            status = "L2CAP channel is nil"
            return
        }
        
        status = "L2CAP Channel Open!"
        self.l2capChannel = channel
        
        // Set up streams for reading and writing
        channel.inputStream.delegate = self
        channel.outputStream.delegate = self
        
        channel.inputStream.schedule(in: .main, forMode: .default)
        channel.outputStream.schedule(in: .main, forMode: .default)
        
        channel.inputStream.open()
        channel.outputStream.open()
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            guard let inputStream = aStream as? InputStream else { return }
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                if let message = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) {
                    receivedMessage = message
                    print("Received: \(message)")
                }
            }
        case .errorOccurred:
            status = "Stream Error"
            disconnect()
        case .endEncountered:
            status = "Stream End"
            disconnect()
        default:
            break
        }
    }
    
    func sendMessage(_ message: String) {
        guard let outputStream = l2capChannel?.outputStream, outputStream.hasSpaceAvailable else {
            status = "Cannot send message."
            return
        }
        let data = message.data(using: .utf8)!
        _ = data.withUnsafeBytes {
            outputStream.write($0.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
        }
        print("Sent: \(message)")
    }
    
    func disconnect() {
        l2capChannel?.inputStream.close()
        l2capChannel?.outputStream.close()
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        status = "Disconnected"
        psm = nil
        targetPeripheral = nil
        l2capChannel = nil
    }
}
