//
//  CustomWindowManager.swift
//  myapp
//
//  Created by Aakash Solanki on 03/09/24.
//

import Foundation
import SwiftUI

class WindowManager {
    static let shared = WindowManager()
    let bluetoothViewModel = ConnectionViewModel.shared
    
    func openNewWindow(title:String = "Preferences", x:Int = 0, y: Int = 0, width:Int = 400, height:Int = 180) {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = title
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.isReleasedWhenClosed = false
    }
}



