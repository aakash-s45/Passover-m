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
        let bundleID = Bundle.main.bundleIdentifier!
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            Logger.viewCycle.warning("Another instance already running, terminating this one")
            NSApp.terminate(nil)
            return
        }
        
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
        clipboardManager = nil
    }
    

    @objc func willSleep() {
//         1. Send "Status: Sleeping" message to Android
        clipboardManager = nil
        networkManager.close()
        Logger.viewCycle.debug("will sleep")
    }

    @objc func didWake() {
        networkManager.start()
        clipboardManager = ClipboardManager()
        
        networkManager.onClipboardMessage = {[weak clipboardManager] message in
            clipboardManager?.addDataToClipboard(data: message)
        }
        
        clipboardManager?.onClipboardUpdate = {[weak networkManager] data in
            networkManager?.sendClipboardData(data: data)
        }
        Logger.viewCycle.debug("did wake")
    }

}
