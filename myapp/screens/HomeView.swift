//
//  HomeView.swift
//  myapp
//
//  Created by Aakash Solanki on 11/05/24.
//

import Foundation
import SwiftUI

struct HomePageView: View {
    @EnvironmentObject var bluetoothViewModel:BluetoothViewModel
    @Environment(\.openWindow) var openWindow
//    let manager = BluetoothManager()

    var body: some View {
        VStack{
            Button("Notify", action: {
                HFDState.shared.update(callHoldState: 1)
            })
            Button("Preferences", action: {
                WindowManager.shared.openNewWindow(title: "Preferences", x: 0, y: 0, width: 600, height: 400)
            })
//            if bleViewModel.isScanning{
//                ScanResults()
//            }
//            else if(bleViewModel.currentDevice != nil){
//                VStack{
//                    CurrentDevice(peripheral: bleViewModel.currentDevice!, rssi: 0)
//                    Button("Preferences", action: {
//                        WindowManager.shared.openNewWindow()
//                    })
//                }
//            }
//            else{
//                Button("Scan", action: {
//                    bleViewModel.startScan()
//                })
//            }
            Button("Scan", action: {

            })
            
            
        }
    }
}
