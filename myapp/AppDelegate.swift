//
//  AppDelegate.swift
//  myapp
//
//  Created by Aakash Solanki on 15/09/24.
//

import Foundation
import AppKit
import OSLog


class AppDelegate: NSObject, NSApplicationDelegate {
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
        Logger.viewCycle.debug("init app delegate"	)
    }
    
    func applicationWillFinishLaunching(_ notification: Notification){
        Logger.viewCycle.debug("app will finish launching")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool{
        Logger.viewCycle.debug("app should not terminate on last window closed")
        return false
    }
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.viewCycle.debug("app launched: \(notification.debugDescription)")
        networkManager.onClipboardMessage = {[weak clipboardManager] message in
            clipboardManager?.addDataToClipboard(data: message)	
        }
        
        clipboardManager?.onClipboardUpdate = {[weak networkManager] data in
            networkManager?.sendClipboardData(data: data)
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
    }
    
    

    func applicationWillTerminate(_ notification: Notification) {
        Logger.viewCycle.debug("app will terminate: \(notification.debugDescription)")
        networkManager.close()
        clipboardManager?.stopMonitoring()
        clipboardManager = nil
    }
    

    @objc func willSleep() {
        // 1. Send "Status: Sleeping" message to Android
        // 2. NetworkManager.close()
        // 3. ClipboardManager.stopMonitoring() (Save CPU)
        
        Logger.viewCycle.debug("will sleep")
    }

    @objc func didWake() {
        // 1. NetworkManager.start()
        // 2. ClipboardManager.startMonitoring()
        Logger.viewCycle.debug("did wake")
    }

}
