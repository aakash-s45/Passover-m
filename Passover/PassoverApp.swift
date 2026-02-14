//
//  PassoverApp.swift
//
//  Created by Aakash Solanki on 03/03/23.
//

import SwiftUI


@main
struct PassoverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true


    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarExtra) {
            Menu()
        } label: {
            Image("PassoverMenuIcon")
                .renderingMode(.template)
        }
        Window("Preferences", id: "preferences-window"){
            PreferencesView().environmentObject(appDelegate.pairingManager)
        }
    }
}


/*
 ISSUES:
 
 - fix connection verifty logic
 - fix reset button, need to clear state better
 
 
 android:
 - add reset button
 - clean things on reset button
 
 
 */
