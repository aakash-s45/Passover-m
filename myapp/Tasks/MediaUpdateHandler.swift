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
}




