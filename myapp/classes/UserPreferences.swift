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
    init() {}
    
    func update(identifier: String) {
        Logger.connection.debug("Updating device: \(identifier)")
        UserDefaults.standard.removeObject(forKey: self.addresskey)
        UserDefaults.standard.setValue(identifier, forKey: self.addresskey)
    }
    
    func clear(){
        UserDefaults.standard.removeObject(forKey: self.addresskey)
    }
    
    func get()->String?{
        return UserDefaults.standard.object(forKey: self.addresskey) as? String
    }
}
