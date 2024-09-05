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

//
//class NotificationManager {
//    static let shared = NotificationManager()
//    
//    private let center = UNUserNotificationCenter.current()
////    private let content = UNMutableNotificationContent()
//    
//    private init() {
//        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
//            if let error = error {
//                print(error.localizedDescription)
//                
//            } else {
//                print("Permission granted")
//                self.setupNotificationActions()
//            }
//        }
//        
//    }
//    
//    func setupNotificationActions() {
//        let acceptAction = UNNotificationAction(identifier: "ACCEPT_ACTION",
//                                                title: "Accept",
//                                                options: [])
//        
//        let rejectAction = UNNotificationAction(identifier: "REJECT_ACTION",
//                                                title: "Reject",
//                                                options: [])
//        
//        let category = UNNotificationCategory(identifier: "PERSISTENT_NOTIFICATION",
//                                              actions: [acceptAction, rejectAction],
//                                              intentIdentifiers: [],
////                                              hiddenPreviewsBodyPlaceholder: "",
//                                              options: [])
//        
//        self.center.setNotificationCategories([category])
//    }
//    
//    func triggerNotification(content: UNMutableNotificationContent) {
////        self.showPersistentAlert()
////        WindowManager.shared.openCallAlert()
//        return
//
//        let id = "call1234"
//        content.sound = .default
//        content.categoryIdentifier = "PERSISTENT_NOTIFICATION"
//        content.interruptionLevel = .active
////        let attachments = UNNotificationAttachment(identifier: <#T##String#>, url: <#T##URL#>)
////        content.attachments =
//        
////        content.
//        
//        
//        
//        
//        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
//        
//        center.add(request) { error in
//            if let error = error {
//                print(error.localizedDescription)
//            }
//        }
//    }
//    
//
//
//    func showPersistentAlert() {
//        let alert = NSAlert()
//        alert.messageText = "Weekly Staff Meeting"
////        alert.informativeText = "Every Tuesday at 2pm"
//        alert.alertStyle = .informational
////        alert.addButton(withTitle: "OK")
////        alert.addButton(withTitle: "Dismiss")
//        
//        if let window = NSApplication.shared.windows.first {
//            
////            alert.beginSheetModal(for: window) { (response) in
////                if response == .alertFirstButtonReturn {
////                    print("OK clicked")
////                } else if response == .alertSecondButtonReturn {
////                    print("Dismiss clicked")
////                }
////            }
//        } else {
//            alert.runModal()
//        }
//    }
//    
//
//
//}
