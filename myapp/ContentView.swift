////
////  ContentView.swift
////  myapp
////
////  Created by Aakash Solanki on 03/03/23.
////
///*
// 
// service -> characteristic -> descriptor
// */
//import SwiftUI
//import UserNotifications
//import CoreBluetooth
//import AVFoundation
//import ISSoundAdditions
//import Cocoa
//
//struct ContentView: View {
//    var body: some View {
//        VStack {
//            Home2()
//        }
//        .padding()
//    }
//}
//
//


// ContentView.swift

import SwiftUI
import OSLog

struct ContentView: View {
    // Observe the shared BluetoothManager instance
    @EnvironmentObject var btManager:BluetoothManager
    @State private var showingPreferences = false

    var body: some View {
        VStack{
            Text(btManager.stateInfo).padding().font(.title)
            if case .idle = btManager.state {
                if btManager.savedDevice == nil{
                    ScanResult()
                }
            }
        }
        HStack{
            if case .connected(_) = btManager.state {
                Image(systemName: "poweroff")
                    .imageScale(.large)
                    .foregroundColor(.white)
                    .onTapGesture {
                        btManager.disconnect()
                    }
            }
            if btManager.savedDevice != nil {
                Image(systemName: "trash")
                    .imageScale(.large)
                    .foregroundColor(.white)
                    .onTapGesture {
                        btManager.clearSavedDeviceAddress()
                    }
            }
            Spacer()
            Image(systemName: "gear").imageScale(.large).foregroundColor(.white).onTapGesture {
                showingPreferences = true
            }
        }
        .padding()
        .frame(width: 250)
        .sheet(isPresented: $showingPreferences) {
            Text("Yo man")
        }
        
    }
}




//struct ContentView: View {
//    @EnvironmentObject var mediaManager: MediaManager
//    @State private var showingPreferences = false
//    
//    var body: some View {
//        VStack {
//            // Status information in menu bar popover
//                Text("Media Status")
//                    .font(.headline)
//            HStack{
//                Text("\(mediaManager.nowPlaying)")
//                    .font(.subheadline)
//                    .padding(.top, 2)
//                if(mediaManager.apiStatus){
//                    Image(systemName: "checkmark.circle.fill")
//                }
//            }
//            
//            Divider()
//                .padding(.vertical, 8)
//            
//            // Menu buttons
//            Button("Preferences...") {
//                // Close the popover before showing preferences
//                if let popover = NSApplication.shared.delegate as? AppDelegate {
//                    popover.closePopover(nil)
//                }
//                
//                // Small delay before showing preferences
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    showingPreferences = true
//                }
//            }
//            .buttonStyle(.plain)
//            .padding(.vertical, 4)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            
//            Button("Quit") {
//                NSApplication.shared.terminate(nil)
//            }
//            .buttonStyle(.plain)
//            .padding(.vertical, 4)
//            .frame(maxWidth: .infinity, alignment: .leading)
//        }
//        .padding()
//        .frame(width: 250)
//        .sheet(isPresented: $showingPreferences) {
//            PreferencesWindow()
//                .frame(minWidth: 450, minHeight: 350)
//        }
//    }
//}


//struct ContentView: View {
//    // Observe the shared BluetoothManager instance
//    @ObservedObject private var btManager = BluetoothManager.shared
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // MARK: - Header
//            HeaderView(
//                state: btManager.state,
//                stateInfo: btManager.stateInfo,
//                isPoweredOn: btManager.isBluetoothPoweredOn
//            )
//
//            
//
//            // MARK: - Main Content
//            if btManager.isBluetoothPoweredOn {
//                switch btManager.state {
//                case .connected(let peripheral):
//                    ConnectedView(peripheral: peripheral)
//                
//                case .scanning, .connecting, .idle:
//                    DeviceListView()
//                    
//                case .powerOff:
//                     // This case is handled by the parent `if`
//                    EmptyView()
//                }
//            } else {
//                PowerOffView()
//            }
//        }
//        .frame(minWidth: 350, minHeight: 450)
//    }
//}


// MARK: - Subviews

private struct HeaderView: View {
    let state: BluetoothConnectionState
    let stateInfo: String
    let isPoweredOn: Bool

    var body: some View {
        VStack {
            Text("macOS Bluetooth Classic")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(stateInfo)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 1)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(headerColor.opacity(0.1))
    }
    
    private var headerColor: Color {
        guard isPoweredOn else { return .gray }
        
        switch state {
        case .idle, .saved:
            return .blue
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .powerOff:
            return .gray
        }
    }
}

private struct DeviceListView: View {
    @EnvironmentObject var btManager:BluetoothManager

    var body: some View {
        VStack {
            List(btManager.pairedDevices) { peripheral in
                Button(action: {
                    Logger.ui.info("Connect button tapped for \(peripheral.name)")
                    btManager.connect(to: peripheral)
                }) {
                    HStack {
                        Text(peripheral.name)
                        Spacer()
                        Text(peripheral.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
}

private struct ConnectedView: View {
    @ObservedObject private var btManager = BluetoothManager.shared
    let peripheral: Peripheral
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "b.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Connected to")
                .font(.headline)
            
            Text(peripheral.name)
                .font(.title.bold())
            
            Text(peripheral.id)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Disconnect") {
                btManager.disconnect()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PowerOffView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "b.circle.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray)
                .padding()
            Text("Bluetooth is Powered Off")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Please turn on Bluetooth in your Mac's System Settings.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

