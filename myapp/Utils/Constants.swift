//
//  Constants.swift
//  myapp
//
//  Created by Aakash Solanki on 22/06/23.
//

import Foundation
import CoreBluetooth

let L2CAP_SERVICE_UUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")

class BLEUtils{
    static let saveIdentifierAddressKey = "ble.savedidentifiers.address"
    static let saveIdentifierNameKey = "ble.savedidentifiers.name"
    static let serverName: String = "cBluetoothServer"
}

