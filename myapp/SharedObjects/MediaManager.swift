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


class MediaManager{
    static let shared = MediaManager()
    
    private var title: String = ""
    private var artist: String = ""
    private var album: String = ""
    private var duration: Double = 0.0
    private var elapsed: Double = 0.0
    private var playbackRate: Bool = false
    private var bundle: String = ""
    private var volume: Float = 0.0
    private var artwork: NSData = NSData(data: Data())
    private var lastPublishedData: String = ""
    private var artworkId: String = ""
    
    private init(){}
    
    func start(){
        MediaRemoteHelper.getNowPlayingInfo()
    }
    
    func reset(){
        self.cleaMediaState()
        MediaRemoteHelper.getNowPlayingInfo()
    }
    
    func stop(){
        MediaRemoteHelper.cleanup()
    }
    
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
        
        self.publishMetaData()
        self.publishArtwork()
        
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

    
    func publishMetaData(overrideData:Bool = false){
        Logger.connection.debug("Publishing media data!")
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
        AppRepository.shared.writeData(data: mediaDataPacket)
    }
    
    func publishArtwork(overrideData: Bool = false){
        let id:String = "\(title)_\(artist)"
        if(id == self.artworkId && !overrideData){
            return
        }
        
        Logger.connection.debug("Sending artwork of size: \(self.artwork.count)")
        self.artworkId = id
        
        guard let pngData = convertTiffToPng(imageData: self.artwork as Data) else {
            Logger.connection.error("no data to segment")
            return
        }
        
        let imagePacket = BPacket.with {
            $0.type = MessageType.graphics
            $0.graphic = Graphic.with{
                $0.seq = Int32(0)
                $0.data = pngData
            }
        }
        
        AppRepository.shared.writeData(data: imagePacket)
    }
}


