//
//  AppDelegate.swift
//  myapp
//
//  Created by Aakash Solanki on 15/09/24.
//

import Foundation
import AppKit


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("app launched")
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
