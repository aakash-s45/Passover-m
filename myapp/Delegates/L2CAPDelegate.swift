//
//  L2cap.swift
//  myapp
//
//  Created by Aakash Solanki on 07/07/24.
//

import Foundation
import IOBluetooth
import OSLog

class L2CAPDelegate: NSObject, IOBluetoothL2CAPChannelDelegate{
    func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        Logger.connection.debug("L2CAP Closed")
    }
    func l2capChannelReconfigured(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        Logger.connection.debug("L2CAP REconfigured")
    }
    func l2capChannelQueueSpaceAvailable(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        Logger.connection.debug("L2CAP l2capChannelQueueSpaceAvailable")
    }
    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status error: IOReturn) {
        Logger.connection.debug("L2CAP open status:\(error)")
        requestMediaTitle(l2capChannel: l2capChannel)
    }
    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        Logger.connection.debug("L2CAP data: \(dataPointer.debugDescription)")
        let receivedData = Data(bytes: dataPointer, count: dataLength)
        processReceivedData(receivedData)
//        let data = Data(bytes: dataPointer, count: Int(dataLength))
//        print("Received Data: \(data)")
//        if let string = String(data: data, encoding: .utf8) {
//            // Use the string here
//            print("Received String data:", string)
//        } else {
//            print("Failed to decode data to string.")
//        }
    }
    func l2capChannelWriteComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        Logger.connection.debug("L2CAP l2capChannelWriteComplete")
    }
    func processReceivedData(_ data: Data) {
            // Print raw data in hexadecimal format
            let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
            print("Hex data: \(hexString)")

            // Example: Parse AVRCP response
            if data.count >= 8 {
                // Extract Transaction ID, Packet Type, Length, PDU ID, and Packet Type
                let transactionID = data[0]
                let packetType = data[1]
                let length = UInt16(data[2]) << 8 | UInt16(data[3])
                let pduID = data[4]
                let packetTypeID = data[5]
                let parameterLength = UInt16(data[6]) << 8 | UInt16(data[7])

                print("Transaction ID: \(transactionID)")
                print("Packet Type: \(packetType)")
                print("Length: \(length)")
                print("PDU ID: \(pduID)")
                print("Packet Type ID: \(packetTypeID)")
                print("Parameter Length: \(parameterLength)")

                var offset = 8
                while offset + 7 < data.count {
                    let attributeID = UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 | UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
                    let valueLength = UInt16(data[offset+4]) << 8 | UInt16(data[offset+5])
                    offset += 6

                    if offset + Int(valueLength) <= data.count {
                        let attributeValueData = data[offset..<(offset + Int(valueLength))]
                        if let attributeValue = String(data: attributeValueData, encoding: .utf8) {
                            print("Attribute ID: \(attributeID)")
                            print("Attribute Value: \(attributeValue)")
                            if attributeID == 0x01 {
                                print("Current playing song name: \(attributeValue)")
                            }
                        } else {
                            print("Failed to decode attribute value")
                        }
                        offset += Int(valueLength)
                    } else {
                        print("Invalid value length")
                        break
                    }
                }
            } else {
                print("Data is too short to contain a valid AVRCP response")
            }
        }
    func processReceivedData1(_ data: Data) {
            // Print raw data in hexadecimal format
            let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
            print("Hex data: \(hexString)")

            // Example: Parse AVRCP response
            if data.count >= 10 {
                // Extract Transaction ID, Packet Type, Length, PDU ID, and Packet Type
                let transactionID = data[0]
                let packetType = data[1]
                let length = UInt16(data[2]) << 8 | UInt16(data[3])
                let pduID = data[4]
                let packetTypeID = data[5]
                let parameterLength = UInt16(data[6]) << 8 | UInt16(data[7])

                print("Transaction ID: \(transactionID)")
                print("Packet Type: \(packetType)")
                print("Length: \(length)")
                print("PDU ID: \(pduID)")
                print("Packet Type ID: \(packetTypeID)")
                print("Parameter Length: \(parameterLength)")

                // Check if we have the attribute count
                if data.count >= 11 {
                    let attributeCount = data[8]
                    print("Number of attributes: \(attributeCount)")

                    var offset = 9
                    for _ in 0..<attributeCount {
                        // Each attribute ID is 4 bytes
                        if offset + 4 <= data.count {
                            let attributeID = UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16 | UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
                            offset += 4
                            print("Attribute ID: \(attributeID)")
                        }
                    }
                }
            } else {
                print("Data is too short to contain a valid AVRCP response")
            }
        }
    
    
    
    func requestMediaTitle(l2capChannel: IOBluetoothL2CAPChannel) {
        let command: [UInt8] = [
                    0x00, // Transaction ID
                    0x00, // Packet Type
                    0x00, 0x11, // Length
                    0x10, 0x00, 0x30, // PDU ID (Get Element Attributes) and Packet Type
                    0x00, 0x01, // Length of parameter
                    0x00, 0x01, // Number of attributes
                    0x00, 0x00, 0x00, 0x01 // Media Attribute ID (Title)
                ]
        
        let commandData = Data(command)
        
        commandData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let pointer = bytes.baseAddress else {
                print("Failed to get base address of command data")
                return
            }
            
            let result = l2capChannel.writeSync(UnsafeMutableRawPointer(mutating: pointer), length: UInt16(commandData.count))
            
            if result != kIOReturnSuccess {
                print("Error writing to L2CAP channel: \(result)")
            } else {
                print("Request sent successfully")
            }
        }
    }
    
}
