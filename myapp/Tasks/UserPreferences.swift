//
//  UserPreferences.swift
//  myapp
//
//  Created by Aakash Solanki on 31/08/24.
//

import Foundation
import os

class UserPreferences{
    private var identifier:String? = nil
    private let addresskey = BLEUtils.saveIdentifierAddressKey
    private let namekey = BLEUtils.saveIdentifierNameKey
    init() {}
    
    func update(identifier: String, name: String) {
        Logger.connection.debug("Updating device: \(identifier), \(name)")
        UserDefaults.standard.removeObject(forKey: self.addresskey)
        UserDefaults.standard.removeObject(forKey: self.namekey)
        UserDefaults.standard.setValue(identifier, forKey: self.addresskey)
        UserDefaults.standard.setValue(name, forKey: self.namekey)
    }
    
    func clear(){
        UserDefaults.standard.removeObject(forKey: self.addresskey)
        UserDefaults.standard.removeObject(forKey: self.namekey)
    }
    
    func get()->[(String)]{
        var response:[(String)] = []
        if let address = UserDefaults.standard.object(forKey: self.addresskey) as? String{
            response.append(address)
            if let name = UserDefaults.standard.object(forKey: self.namekey) as? String{
                response.append(name)
            }
        }
        Logger.connection.debug("Found saved device setting: \(response.description)")
        return response
    }
}
