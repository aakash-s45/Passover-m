//
//  HomeView.swift
//  myapp
//
//  Created by Aakash Solanki on 11/05/24.
//

import Foundation
import SwiftUI

struct HomePageView: View {
    @EnvironmentObject var bleViewModel:BLEViewModel
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack{
            if bleViewModel.isScanning{
                ScanResults()
            }
            else if(bleViewModel.currentDevice != nil){
                VStack{
                    CurrentDevice(peripheral: bleViewModel.currentDevice!, rssi: 0)
                    Button("Preferences", action: {
                        WindowManager.shared.openNewWindow()
                    })
                }
            }
            else{
                Button("Scan", action: {
                    bleViewModel.startScan()
                })
            }
        }
    }
}
