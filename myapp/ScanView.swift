//
//  ScanView.swift
//  myapp
//
//  Created by Aakash Solanki on 11/05/24.
//

import Foundation
import SwiftUI
import CoreBluetooth

struct ScanResults: View {
    @EnvironmentObject var bleViewModel: BLEViewModel
    var body: some View {
        Text("Scan Result").font(.headline)
        List(bleViewModel.scanResults.sorted(by: { $0.value.intValue < $1.value.intValue }), id: \.key) { pair in
                    let peripheral = pair.key
                    let value = pair.value
                    DeviceRowView(peripheral: peripheral, rssi: value).onTapGesture {
                        bleViewModel.connectToDevice(peripheral: peripheral)
                    }
        
        }
        Button("Stop Scan", action: {
            bleViewModel.stopScan()
        })
    }
}


struct DeviceRowView: View {
    let peripheral: CBPeripheral
    let rssi: NSNumber

    var body: some View {
        HStack {
            Text(peripheral.name ?? "Unknown Device")
            Spacer()
            RSSIColorDotView(rssi: rssi.intValue)
        }
        .padding()
    }
}

struct RSSIColorDotView: View {
    let rssi: Int


    var body: some View {
        print(rssi)
        let color: Color
        
        switch rssi {
       case ..<(-90):
           color = .red
       case (-90)..<(-70):
           color = .yellow
       case (-70)..<(-50):
           color = .orange
       case (-50)...:
           color = .green
       default:
           color = .gray
        }
        return Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}


struct CurrentDevice : View{
    let peripheral: CBPeripheral
    let rssi: Int
    @EnvironmentObject var bleViewModel:BLEViewModel
    var body: some View {
        VStack{
            Text("Current Device").font(.headline)
            DeviceRowView(peripheral: peripheral, rssi: 0)
        }
    }
}
