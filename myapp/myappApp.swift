//
//  myappApp.swift
//  myapp
//
//  Created by Aakash Solanki on 03/03/23.
//

import SwiftUI




@main
struct myappApp: App {
    let bluetoothViewModel = ConnectionViewModel.shared
    let handsFreeDeviceState = HFDState.shared
    
    var body: some Scene {
        MenuBarExtra("Passover", systemImage: "iphone.gen2.circle.fill"){
            ContentView().environmentObject(bluetoothViewModel).environmentObject(handsFreeDeviceState)
        }.menuBarExtraStyle(.window)

    }
}
