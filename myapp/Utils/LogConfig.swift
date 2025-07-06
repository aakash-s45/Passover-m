import Foundation
import OSLog

extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like a view that appeared.
    static let connection = Logger(subsystem: subsystem, category: "connection")

    /// All logs related to tracking and analytics.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewCycle")
    
    /// A logger for UI-related events.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}

