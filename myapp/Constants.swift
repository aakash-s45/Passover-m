//
//  Constants.swift
//  myapp
//
//  Created by Aakash Solanki on 22/06/23.
//

import Foundation
import CoreBluetooth

class BLEUtils{
    static let serviceID = CBUUID(string: "0000b81d-0000-1000-8000-00805f9b34fb")
    static let serviceID1 = CBUUID(string: "15006156-c8fa-4ae8-9c73-2ad4c2d1a850")
    static let characteristicID = CBUUID(string: "36d4dc5c-814b-4097-a5a6-b93b39085928")
    static let characteristicID2 = CBUUID(string: "7db3e235-3608-41f3-a03c-955fcbd2ea4b")
    static let descriptor1 = CBUUID(string: "0A5A4BB4-DF40-4707-B433-D439462CAE5D")
    static let descriptor2 = CBUUID(string: "386AA42F-5FA5-4A82-B60E-49C08E450053")
    static let desData1 = "Send Characteristic".data(using: .utf8)
    static let desData2 = "Confirm Characteristic".data(using: .utf8)
    
    static let saveIdentifierKey = "ble.savedidentifiers"
}

class MediaInfo{
    static let title = "kMRMediaRemoteNowPlayingInfoTitle"
    static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
    static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsed = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
    static let artwork = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let bundle = "cusomtBundleIdentifier"
}
