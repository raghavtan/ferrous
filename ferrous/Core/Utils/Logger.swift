import Foundation
import Logging

/// A centralized logging system for the app.
final class FerrousLogger {
    // Single shared instance
    static let shared = FerrousLogger()

    // Loggers for different subsystems
    private(set) var app: Logger
    private(set) var network: Logger
    private(set) var kubernetes: Logger
    private(set) var github: Logger
    private(set) var tools: Logger

    private init() {
        // Create loggers for different subsystems first
        app = Logger(label: "com.onefootball.ferrous.app")
        network = Logger(label: "com.onefootball.ferrous.network")
        kubernetes = Logger(label: "com.onefootball.ferrous.kubernetes")
        github = Logger(label: "com.onefootball.ferrous.github")
        tools = Logger(label: "com.onefootball.ferrous.tools")

        // Now we can safely call methods that use self
        // Set log level after initializing all properties
        let logLevel = getLogLevel()

        // Configure each logger with the appropriate level
        app.logLevel = logLevel
        network.logLevel = logLevel
        kubernetes.logLevel = logLevel
        github.logLevel = logLevel
        tools.logLevel = logLevel

        // Setup custom log handler if needed (could log to file)
        setupLogHandler()
    }

    private func getLogLevel() -> Logger.Level {
        // Check for log level in environment variables
        if let envLevel = ProcessInfo.processInfo.environment["FERROUS_LOG_LEVEL"] {
            switch envLevel.lowercased() {
            case "trace": return .trace
            case "debug": return .debug
            case "info": return .info
            case "notice": return .notice
            case "warning": return .warning
            case "error": return .error
            case "critical": return .critical
            default: return .info
            }
        }

        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }

    private func setupLogHandler() {
        // Optional: Set up custom log handler for file logging if needed
        // For now, we'll just use the default console logger
    }
}

/// Extension to provide easy access to loggers
extension FerrousLogger {
    /// App-level operations
    static var app: Logger { shared.app }

    /// Network operations
    static var network: Logger { shared.network }

    /// Kubernetes operations
    static var kubernetes: Logger { shared.kubernetes }

    /// GitHub operations
    static var github: Logger { shared.github }

    /// Tools checking
    static var tools: Logger { shared.tools }
}