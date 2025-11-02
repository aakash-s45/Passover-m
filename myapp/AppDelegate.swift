//
//  AppDelegate.swift
//  myapp
//
//  Created by Aakash Solanki on 15/09/24.
//

import Foundation
import AppKit


class AppDelegate: NSObject, NSApplicationDelegate {
//    var bluetoothClient:BluetoothL2capClient?

    var pairingManager: PairingManager
    var networkManager: NetworkManager
    var clipboardManager: ClipboardManager?
    
    override init() {
        pairingManager = PairingManager()
        networkManager = NetworkManager.shared
        networkManager.configure(pairingManager: pairingManager)
        networkManager.start()
        clipboardManager = ClipboardManager()
        
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("app launched")
        networkManager.onClipboardMessage = {[weak clipboardManager] message in
            clipboardManager?.addDataToClipboard(data: message)
        }
        
        clipboardManager?.onClipboardUpdate = {[weak networkManager] data in
            networkManager?.sendClipboardData(data: data)
        }
    }
    

    func applicationWillTerminate(_ notification: Notification) {
        print("app will terminate")
        networkManager.close()
        clipboardManager = nil
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

}
