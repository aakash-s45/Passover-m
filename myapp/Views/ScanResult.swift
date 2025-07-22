//
//  ScanResult.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI
import IOBluetooth


struct ScanResult: View {
    @EnvironmentObject var blueManager: BluetoothManager
    
    var body: some View {
        VStack{
            List(blueManager.pairedDevices, id:\.id) { device in
                HStack{
                    Image(systemName: "circle.filled.iphone.fill").imageScale(.medium)
                    Text(device.name)
                }
                .listRowSeparator(.visible, edges: .all)
                .listRowSeparatorTint(.gray.opacity(0.5), edges: .all)
                .padding(3)
                .onTapGesture {
                    blueManager.connect(to: device)
                }
            }
        }
    }
}

