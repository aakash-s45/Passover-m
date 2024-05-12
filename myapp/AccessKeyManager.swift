//
//  AccessKeyManager.swift
//  myapp
//
//  Created by Aakash Solanki on 11/05/24.
//

import Foundation
import CryptoKit

import CryptoKit

class AccessKeyManager {
    static let shared = AccessKeyManager()
    
    private var currentKey: String? = nil
    private let keySize: Int = 32
    private let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    private init() {
        currentKey = self.generateAccessKey()
    }
    
    private func generateAccessKey() -> String {
        return String((0..<keySize).map { _ in letters.randomElement()! })
    }
    
    func getCurrentKey() -> String {
        if currentKey == nil{
            currentKey = self.generateAccessKey()
        }
        return currentKey!
    }
    
    func getKeyData()->BPacket{
        let akey = self.getCurrentKey()
        return BPacket(type: "A", seq: Int32(akey.count), data: akey.data(using: .utf8)!)
    }
    
    
    func rotateKey() {
        self.currentKey = self.generateAccessKey()
    }
}


