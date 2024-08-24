//
//  CentralManager.swift
//  myapp
//
//  Created by Aakash Solanki on 23/06/24.
//

import Foundation
import CoreBluetooth
import IOBluetooth


class BluetoothManager: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    private var rfcommClient: RFCommClient?
//    private var bluetoothClient: BluetoothClient?

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        rfcommClient = RFCommClient()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            let device = IOBluetoothDevice(addressString: "98-09-cf-a5-f2-ef")
            rfcommClient?.connect(to: device!)
//            bluetoothClient?.discoverAndConnect()
        case .poweredOff:
            rfcommClient?.stop()
            print("Bluetooth is powered off")
        case .resetting:
            rfcommClient?.stop()
            print("Bluetooth is resetting")
        case .unauthorized:
            rfcommClient?.stop()
            print("Bluetooth is unauthorized")
        case .unsupported:
            rfcommClient?.stop()
            print("Bluetooth is unsupported on this device")
        case .unknown:
            rfcommClient?.stop()
            print("Bluetooth state is unknown")
        @unknown default:
            fatalError()
        }
    }
}
