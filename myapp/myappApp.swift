//
//  myappApp.swift
//  myapp
//
//  Created by Aakash Solanki on 03/03/23.
//

import SwiftUI


@main
struct myappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let bluetoothViewModel = ConnectionViewModel.shared
    let handsFreeDeviceState = HFDState.shared
    
    var body: some Scene {
        MenuBarExtra("Passover", systemImage: "macbook.and.iphone"){
            ContentView().environmentObject(bluetoothViewModel).environmentObject(handsFreeDeviceState)
        }.menuBarExtraStyle(.window)

    }
}


/*
 create-dmg \
   --volname "Passover Installer" \
   --volicon "/Users/aakash/Desktop/icon/Passover.icns" \
   --window-pos 200 120 \
   --window-size 800 400 \
   --icon-size 100 \
   --icon "Passover.app" 200 190 \
   --hide-extension "Passover.app" \
   --app-drop-link 600 185 \
   "Passover-Installer.dmg" \
   "/Users/aakash/Downloads/Passover 2024-09-16 12-59-58"
 
 */
