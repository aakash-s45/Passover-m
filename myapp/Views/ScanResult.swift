//
//  ScanResult.swift
//  myapp
//
//  Created by Aakash Solanki on 01/09/24.
//

import SwiftUI
import IOBluetooth


struct ScanResult: View {
    @EnvironmentObject var bluetoothViewModel: ConnectionViewModel
    
    var body: some View {
        VStack{
            if bluetoothViewModel.is_scanning{
                Text("Scanning").font(.headline)
            }
            else{
                Text("Nearby Devices").font(.headline)
            }
            List(bluetoothViewModel.scanResult, id:\.addressString) { device in
                HStack{
                    Image(systemName: "circle.filled.iphone.fill").imageScale(.medium)
                    Text(device.nameOrAddress)
                }
                .listRowSeparator(.visible, edges: .all)
                .listRowSeparatorTint(.gray.opacity(0.5), edges: .all)
                .padding(3)
                .onTapGesture {
                    AppRepository.shared.stopInquiry()
                    AppRepository.shared.select(device: device)
                }
            }
            if bluetoothViewModel.is_scanning{
                Button("Stop Scan", action: {
                    AppRepository.shared.stopInquiry()
                })
            }
        }
    }
}

