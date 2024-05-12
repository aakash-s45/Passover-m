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





struct ContentView: View {
    

//    let center = UNUserNotificationCenter.current()
//    let content = UNMutableNotificationContent()
//    init(){
//        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
//            if let error = error {
//                print(error.localizedDescription)
//            }
//            else{
//                print("Permisson granted")
//            }
//            
//        }
//        content.title = "Weekly Staff Meeting"
//        content.body = "Every Tuesday at 2pm"
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
//        _ = UNNotificationRequest(identifier: "Identifier", content: content, trigger: trigger)
////        center.add( request){error in
////            if let error = error{
////                print(error)
////            }
////        }
//    }

    
    var body: some View {
        VStack {
            HomePageView()
        }
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



