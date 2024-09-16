import Foundation
import OSLog

class MediaRemoteHelper {
    static var observation: NSObjectProtocol?
    static var counter = 0
    static var debounceTimer: Timer?
    static var mediaObj = MediaManager.shared
    
    // Static properties to hold framework function pointers
    static var MRMediaRemoteGetNowPlayingInfo: ((DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)?
    static var MRNowPlayingClientGetBundleIdentifier: ((AnyObject?) -> String)?
    static var MRMediaRemoteRegisterForNowPlayingNotificationsIdentifier: ((DispatchQueue) -> Void)?
    static var MRMediaRemoteSendCommand: ((Int, AnyObject?) -> Void)?
    static var MRMediaRemoteSetElapsedTime: ((Double) -> Void)?

    static func getNowPlayingInfo() {
        loadMediaRemoteFramework()
        fetchNowPlayingInfo(nil)
        setupNowPlayingInfoDidChangeObserver()
    }

    static func setupNowPlayingInfoDidChangeObserver() {
        observation = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil, queue: nil) { notification in

            let bundleIdentifier:String? = (notification.userInfo ?? [:])["kMRMediaRemoteNowPlayingApplicationDisplayNameUserInfoKey"] as? String
            debounceNowPlayingInfo(bundleIdentifier)
        }
    }

    static func fetchNowPlayingInfo(_ bundleIdentifier: String?) {
        guard let MRMediaRemoteGetNowPlayingInfo = MRMediaRemoteGetNowPlayingInfo else {
            Logger.connection.error("MRMediaRemoteGetNowPlayingInfo is not available")
            return
        }

        let mainQueue = DispatchQueue.main
                
        MRMediaRemoteGetNowPlayingInfo(mainQueue) { information in
//            Logger.connection.debug("all info: \(information.debugDescription)")
            var customInfo = information
            customInfo["cusomtBundleIdentifier"] = bundleIdentifier
            mediaObj.updateMediaInfo(info:customInfo)
        }
    }

    static func debounceNowPlayingInfo(_ bundleIdentifier:String?) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in
            fetchNowPlayingInfo(bundleIdentifier)
        }
    }

    static func cleanup() {
        if let observation = MediaRemoteHelper.observation {
            NotificationCenter.default.removeObserver(observation)
        }
    }

    static func loadMediaRemoteFramework() {
        let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        // Get a Swift function for MRMediaRemoteGetNowPlayingInfo
        guard let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { return }
        typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        
        // Get a Swift function for MRMediaRemoteSendCommand
        guard let MRMediaRemoteSendCommandPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else { return }
        typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int, AnyObject?) -> Void
        MRMediaRemoteSendCommand = unsafeBitCast(MRMediaRemoteSendCommandPointer, to: MRMediaRemoteSendCommandFunction.self)
        

        // Get a Swift function for MRMediaRemoteSetElapsedTime
        guard let MRMediaRemoteSetElapsedTimePointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) else { return }
        typealias MRMediaRemoteSetElapsedTimeFunction = @convention(c) (Double) -> Void
        MRMediaRemoteSetElapsedTime = unsafeBitCast(MRMediaRemoteSetElapsedTimePointer, to: MRMediaRemoteSetElapsedTimeFunction.self)
        
        // Get a Swift function for MRNowPlayingClientGetBundleIdentifier
        guard let MRNowPlayingClientGetBundleIdentifierPointer = CFBundleGetFunctionPointerForName(bundle, "MRNowPlayingClientGetBundleIdentifier" as CFString) else { return }
        typealias MRNowPlayingClientGetBundleIdentifierFunction = @convention(c) (AnyObject?) -> String
        MRNowPlayingClientGetBundleIdentifier = unsafeBitCast(MRNowPlayingClientGetBundleIdentifierPointer, to: MRNowPlayingClientGetBundleIdentifierFunction.self)

        guard let MRMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) else { return }
        typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
        let MRMediaRemoteRegisterForNowPlayingNotificationsIdentifier = unsafeBitCast(MRMediaRemoteRegisterForNowPlayingNotificationsPointer, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
        let mainQueue = DispatchQueue.main
        MRMediaRemoteRegisterForNowPlayingNotificationsIdentifier(mainQueue)
        
    }
    
    static func previousTrack() {
        guard let MRMediaRemoteSendCommand = MRMediaRemoteSendCommand else {
            print("MRMediaRemoteSendCommand is not available")
            return
        }
        MRMediaRemoteSendCommand(MediaRemoteCommands.previousTrack, nil)
    }

    
    static func nextTrack() {
        guard let MRMediaRemoteSendCommand = MRMediaRemoteSendCommand else {
            print("MRMediaRemoteSendCommand is not available")
            return
        }
        MRMediaRemoteSendCommand(MediaRemoteCommands.nextTrack, nil) // Command for NextTrack
    }
    
    static func setElapsedTime(_ elapsedTime: Double) {
        guard let MRMediaRemoteSetElapsedTime = MRMediaRemoteSetElapsedTime else {
            print("MRMediaRemoteSetElapsedTime is not available")
            return
        }
        MRMediaRemoteSetElapsedTime(elapsedTime)
    }
}


struct MediaRemoteCommands {
    static let play = 0
    static let pause = 1
    static let togglePlayPause = 2
    static let stop = 3
    static let nextTrack = 4
    static let previousTrack = 5
    static let advanceShuffleMode = 6
    static let advanceRepeatMode = 7
    static let beginFastForward = 8
    static let endFastForward = 9
    static let beginRewind = 10
    static let endRewind = 11
    static let rewind15Seconds = 12
    static let fastForward15Seconds = 13
    static let rewind30Seconds = 14
    static let fastForward30Seconds = 15
    static let toggleRecord = 16
    static let skipForward = 17
    static let skipBackward = 18
    static let changePlaybackRate = 19
    static let rateTrack = 20
    static let likeTrack = 21
    static let dislikeTrack = 22
    static let bookmarkTrack = 23
    static let seekToPlaybackPosition = 24
    static let changeRepeatMode = 25
    static let changeShuffleMode = 26
    static let enableLanguageOption = 27
    static let disableLanguageOption = 28
}




