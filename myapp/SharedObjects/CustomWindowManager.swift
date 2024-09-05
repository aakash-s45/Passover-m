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
    var callAlert:NSWindow? = nil
    var callPopUp:NSWindow? = nil
    

    func openNewWindow(title:String = "Preferences", x:Int = 0, y: Int = 0, width:Int = 400, height:Int = 180) {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = title
//        newWindow.contentView = NSHostingView(rootView: DeviceControlPane().environmentObject(bluetoothViewModel))
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.isReleasedWhenClosed = false
    }
    
    enum WindowType{
        case CallAlert, CallPopUP
    }
    
    func openCallAlert(windowName: WindowType) {
        if windowName == .CallAlert{
            if self.callAlert != nil{
                return
            }
        }
        else{
            if self.callPopUp != nil{
                return
            }
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 30),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Hello"
        window.level = .popUpMenu
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        if windowName == .CallAlert{
            window.contentView = NSHostingView(rootView: CallAlert().environmentObject(HFDState.shared))
        }
        else{
            window.contentView = NSHostingView(rootView: ActiveCall().environmentObject(HFDState.shared))
        }
        window.setFrameTopLeftPoint(NSPoint(x: 1120, y: 850))
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        if windowName == .CallAlert{
            self.callAlert = window
        }
        else{
            self.callPopUp = window
        }
    }
    
    func closeCallAlert(windowName: WindowType){
        if windowName == .CallAlert{
            self.callAlert?.close()
            self.callAlert = nil
        }
        else{
            self.callPopUp?.close()
            self.callPopUp = nil
        }

    }
}



