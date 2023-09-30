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


struct ContentView: View {
    var msg = "hello app"
    @ObservedObject var bleManager = BLEPeripheral()
//    @ObservedObject var bleManager = BLEServer()
    @ObservedObject var centralManager = BLEClient()
    
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    init(){
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print(error.localizedDescription)
            }
            else{
                print("Permisson granted")
            }
            
        }
        content.title = "Weekly Staff Meeting"
        content.body = "Every Tuesday at 2pm"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "Identifier", content: content, trigger: trigger)
//        center.add( request){error in
//            if let error = error{
//                print(error)
//            }
//        }
    }
    
    
    
    
    
    
    
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            if bleManager.isSwitchedOn{
                Text("Bluetooth on")
            }
            else{
                Text(msg)
            }
            
            if !bleManager.msg.isEmpty{
                Text(bleManager.msg)

            }
            ScanPage(centralManager: centralManager)

            
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ScanPage:View{
    @ObservedObject var centralManager:BLEClient


    var body: some View{
        VStack{
            if(!centralManager.isConnected){
                Text("Bluetooth Status: \(String(centralManager.isSwitchedOn))")
                Button("Start Scan",action: {
                    centralManager.scanResults.removeAll()
                    self.centralManager.startScan()
                })
                if(centralManager.isScanning){
                    Text("Scanning")
                }
            }
            if(centralManager.isConnected){
                Button("Disconnect",action: {
                    centralManager.disconnnectDevice()
                })
            }

            Text("------------- Select device to connect -----------")
            ForEach(Array(self.centralManager.scanResults.values),id: \.identifier){peripheral in
                Text(peripheral.name!).onTapGesture {
                    if(centralManager.isScanning){
                        centralManager.stopScan()
                    }
                    centralManager.connectToDevice(peripheral: peripheral)
                }
            }
            if(centralManager.isConnected){
                ChatPage(centralManager:centralManager)
            }
            
        }
        
    }
    
}

struct ChatPage:View{

    @State private var message:String = ""
    var centralManager:BLEClient
    
    var body: some View{
        VStack{
            TextField("Write the message", text: $message).padding()
            Text(message)
            if(centralManager.isCharFound){
                Button("Send", action: {
                    centralManager.sendMessage(message: message)
                    message = ""
                    
                })
            }
        }
    }
    
}
