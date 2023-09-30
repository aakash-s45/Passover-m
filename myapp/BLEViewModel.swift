//
//  BLEViewModel.swift
//  myapp
//
//  Created by Aakash Solanki on 23/06/23.
//

import Foundation

class BLEViewModel:NSObject,ObservableObject{
    @Published var isSwitchedOn = false
    @Published var msg:String = ""
    func updateSwitchStatus(status:Bool){
        self.isSwitchedOn = status
    }
    func updateMessage(msg:String){
        self.msg = msg
    }
}
