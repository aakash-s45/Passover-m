//
//  AppDelegate.swift
//  myapp
//
//  Created by Aakash Solanki on 15/09/24.
//

import Foundation
import AppKit


class AppDelegate: NSObject, NSApplicationDelegate {
//    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("app launched")
//        print("App launched")
//        let statusBar = NSStatusBar.system
//        statusBarItem = statusBar.statusItem(withLength: 16)
//
//        let button = statusBarItem.button
//        button?.image = NSImage(named: "")
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        print("app active")
    }
    
    func applicationWillBecomeActive(_ notification: Notification) {
        print("becoming active")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("app will terminate")
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        print("becoming inactive")
    }
}
