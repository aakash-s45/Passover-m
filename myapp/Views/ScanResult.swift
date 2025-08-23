//
//  ScanResult.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI
import CoreBluetooth

struct ScanResult: View {
    @EnvironmentObject var bluetoothClient: BluetoothL2capClient

    private var discoveredPeripheralsList: [(peripheral: CBPeripheral, psm: CBL2CAPPSM)] {
        bluetoothClient.discoveredPeripherals.map { ($0.key, $0.value) }
    }

    var body: some View {
        List(discoveredPeripheralsList, id: \.peripheral.identifier) { item in
            HStack {
                Image(systemName: "circle.filled.iphone.fill").imageScale(.medium)
                Text(item.peripheral.name ?? "Unknown")
            }
            .listRowSeparator(.visible, edges: .all)
            .listRowSeparatorTint(.gray.opacity(0.5), edges: .all)
            .padding(3)
            .onTapGesture {
                bluetoothClient.connect(to: item.peripheral, using: item.psm)
            }
        }
    }
}


