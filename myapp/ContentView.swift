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
    @ObservedObject private var btManager = BluetoothManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HeaderView(
                state: btManager.state,
                stateInfo: btManager.stateInfo,
                isPoweredOn: btManager.isBluetoothPoweredOn
            )

            

            // MARK: - Main Content
            if btManager.isBluetoothPoweredOn {
                switch btManager.state {
                case .connected(let peripheral):
                    ConnectedView(peripheral: peripheral)
                
                case .scanning, .connecting, .idle:
                    DeviceListView()
                    
                case .powerOff:
                     // This case is handled by the parent `if`
                    EmptyView()
                }
            } else {
                PowerOffView()
            }
        }
        .frame(minWidth: 350, minHeight: 450)
    }
}


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
        case .idle, .scanning:
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
    @ObservedObject private var btManager = BluetoothManager.shared

    var body: some View {
        VStack {
            List(btManager.discoveredPeripherals) { peripheral in
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
                .buttonStyle(.plain) // Use plain style to make the whole row clickable
            }
            
            Spacer()
            
            if btManager.state == .scanning {
                Button("Stop Scanning") {
                    btManager.stopScanning()
                }
                .padding()
            } else {
                Button("Scan for Devices") {
                    btManager.startScanning()
                }
                .keyboardShortcut("r", modifiers: .command)
                .padding()
            }
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

