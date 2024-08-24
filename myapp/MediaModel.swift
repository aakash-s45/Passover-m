//
//  MediaModel.swift
//  myapp
//
//  Created by Aakash Solanki on 07/04/24.
//

import Foundation
import Compression
import CoreBluetooth
import AppKit
import ISSoundAdditions
import OSLog
import SwiftProtobuf


/*
 Artist: Good Neighbours
 Title: Home
 Album: Home
 Duration: 157.4935
 ElapsedTime: 63.3613334569996
 Playback Rate: 1
 ArtWork Identifier: 4221699
 ContentItemIdentifier: 4221699
 Bundle identifier: Optional("Safari")
 
 
 
 ["kMRMediaRemoteNowPlayingInfoPlaybackRate": 1, "kMRMediaRemoteNowPlayingInfoTitle": Hey Girl, "kMRMediaRemoteNowPlayingInfoArtist": Stephen Sanchez, "kMRMediaRemoteNowPlayingInfoArtworkMIMEType": image/jpeg, "kMRMediaRemoteNowPlayingInfoAlbum": Easy On My Eyes, "kMRMediaRemoteNowPlayingInfoUniqueIdentifier": 10511281, "kMRMediaRemoteNowPlayingInfoArtworkData": <4d4d002a 00003848 fffcfbff f8ffffff f7ffffff fcffffff fdfcffff fcffffff  fdbafe4b fedcff6d ffff>, "kMRMediaRemoteNowPlayingInfoDuration": 185.9135, "kMRMediaRemoteNowPlayingInfoContentItemIdentifier": 10511281, "kMRMediaRemoteNowPlayingInfoElapsedTime": 78.41929404099865, "kMRMediaRemoteNowPlayingInfoArtworkIdentifier": 10511281, "kMRMediaRemoteNowPlayingInfoTimestamp": 2024-04-07 09:16:30 +0000, "kMRMediaRemoteNowPlayingInfoArtworkDataWidth": 60, "kMRMediaRemoteNowPlayingInfoArtworkDataHeight": 60]
 
 */

class MediaManager{
    static let shared = MediaManager()
    
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var duration: Double = 0.0
    var elapsed: Double = 0.0
    var playbackRate: Bool = false
    var bundle: String = ""
    var volume: Float = 0.0
    var artwork: NSData = NSData(data: Data())
    private var lastPublishedData: String = ""
    private var artworkId: String = ""
    
    private init(){}
    
    func updateMediaInfo(info: [String: Any], override:Bool = false){
        self.title = info[MediaInfo.title] as? String ?? ""
        self.artist = info[MediaInfo.artist] as? String ?? ""
        self.album = info[MediaInfo.album] as? String ?? ""
        self.duration = Double(truncating: info[MediaInfo.duration] as? NSNumber ?? 0.0)
        self.elapsed = Double(truncating: info[MediaInfo.elapsed] as? NSNumber ?? 0.0)
        self.playbackRate = info[MediaInfo.playbackRate] as? Bool ?? false
        self.artwork = info[MediaInfo.artwork] as? NSData ?? NSData(data: Data())
        self.bundle = info[MediaInfo.bundle] as? String ?? ""
        self.volume = Sound.output.volume
        Logger.connection.debug("MediaData Updated!: \(self.getMediaData())")
        publishData()
        
        let _artworkId:String = "\(title)_\(artist)"
        if(_artworkId != self.artworkId){
            print("artwork size: \(artwork.count)")
            self.artworkId = _artworkId
                        self.segmentData()

        }
        
    }
    
    func cleaMediaState(){
        self.artworkId = ""
        self.lastPublishedData = ""
    }
    
    
    func getMediaData() -> String {
        return "M_\(title)_\(artist)_\(album)_\(duration)_\(elapsed)_\(playbackRate)_\(bundle)_\(volume)"
    }
    

    func getCurrentTimestamp() -> Google_Protobuf_Timestamp {
        let currentDate = Date()
        var timestamp = Google_Protobuf_Timestamp()

        timestamp.seconds = Int64(currentDate.timeIntervalSince1970)
        timestamp.nanos = Int32((currentDate.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000_000)
        
        return timestamp
    }

    
    func publishData(overrideData:Bool = false){
        Logger.connection.debug("Publishing media data!")
        let conenctionState = BluetoothViewModel.shared.connectionState
        let message = MediaManager.shared.getMediaData()
        if(message == lastPublishedData && !overrideData){
            Logger.connection.debug("Publishing message not changed!")
            return
        }
        
        let mediaDataPacket = BPacket.with {
            $0.type = MessageType.mediadata
            $0.mediaData = MediaData.with({
                $0.title = self.title
                $0.artist = self.artist
                $0.album = self.album
                $0.duration = self.duration
                $0.elapsed = self.elapsed
                $0.playbackRate = self.playbackRate
                $0.bundle = self.bundle
                $0.volume = self.volume
                $0.timestamp = getCurrentTimestamp()
            })
        }
        
        do{
            let mediaData:Data = try mediaDataPacket.serializedData()
            lastPublishedData = message
            conenctionState.writeData(data: mediaData)
        }catch let error{
            Logger.connection.error("Failed to create mediaDataPacket to send due to \(error)")
        }
    }
    
    
    func segmentData(){
        let packetManager = PacketManager.shared
        if !self.artwork.isEmpty{
            Logger.connection.debug("segmentData request")
            let pngData = convertTiffToPng(imageData: self.artwork as Data)
            if pngData == nil {
                Logger.connection.error("no data to segment")
                return
            }
            //            if need to resize the image, resize here
            packetManager.segmentData(data: pngData!)
            
        }
        else{
            Logger.connection.error("not data to segment")
        }
        
    }
    
}

