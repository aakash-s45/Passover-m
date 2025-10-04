//
//  AppDelegate.swift
//  myapp
//
//  Created by Aakash Solanki on 15/09/24.
//

import Foundation
import AppKit


class AppDelegate: NSObject, NSApplicationDelegate {
    var bluetoothClient:BluetoothL2capClient?
    var clipboardManager:ClipboardManager?
    var networkManager:NetworkManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("app launched")
    }
    func applicationWillBecomeActive(_ notification: Notification) {
        bluetoothClient = BluetoothL2capClient.shared
        clipboardManager = ClipboardManager.shared
        networkManager = NetworkManager.shared
        clipboardManager?.bluetoothClient = bluetoothClient
        
        print("becoming active")
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        _ = bluetoothClient?.startScan()
        print("app active")
        
    }
    func applicationWillResignActive(_ notification: Notification) {
        print("becoming inactive")
    }
    func applicationWillTerminate(_ notification: Notification) {
        print("app will terminate")
        bluetoothClient?.disconnect()
    }
}
