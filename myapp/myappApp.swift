//
//  myappApp.swift
//  myapp
//
//  Created by Aakash Solanki on 03/03/23.
//

import SwiftUI

@main
struct myappApp: App {
    var body: some Scene {
        MenuBarExtra("Syncify", systemImage: "macpro.gen3"){
            ContentView()
        }.menuBarExtraStyle(.window)
//        WindowGroup {
////            ContentView()
//        }
    }
}
