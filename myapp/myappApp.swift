//
//  myappApp.swift
//  myapp
//
//  Created by Aakash Solanki on 03/03/23.
//

import SwiftUI

@main
struct myappApp: App {
    let bleViewModel = BLEViewModel.shared
    var body: some Scene {
        
        MenuBarExtra("Syncify", systemImage: "macpro.gen3"){
            ContentView().environmentObject(bleViewModel)
        }.menuBarExtraStyle(.window)

    }
}

class WindowManager {
    static let shared = WindowManager()
    let bleViewModel = BLEViewModel.shared
    

    func openNewWindow() {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Preferences"
        newWindow.contentView = NSHostingView(rootView: NewWindow().environmentObject(bleViewModel))
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.isReleasedWhenClosed = false
    }
}


