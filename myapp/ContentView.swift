//
//  ContentView.swift
//  myapp
//
//  Created by Aakash Solanki on 03/03/23.
//
/*
 
 service -> characteristic -> descriptor
 */
import SwiftUI
import UserNotifications
import CoreBluetooth
import AVFoundation
import ISSoundAdditions
import Cocoa

struct ContentView: View {
    var body: some View {
        VStack {
            Home()
        }
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
