import Foundation

enum AppLogger {
    static func debug(_ message: @autoclosure () -> String) {
        log("DEBUG", message())
    }

    static func info(_ message: @autoclosure () -> String) {
        log("INFO", message())
    }

    static func warning(_ message: @autoclosure () -> String) {
        log("WARNING", message())
    }

    static func error(_ message: @autoclosure () -> String) {
        log("ERROR", message())
    }

    private static func log(_ level: String, _ message: String) {
        #if DEBUG
        print("[Bubble][\(level)] \(message)")
        #endif
    }
}
