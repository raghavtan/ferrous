import Cocoa
import SwiftUI

/// Application delegate for handling app lifecycle
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The status bar controller
    private var statusBarController: StatusBarController?

    /// Logger instance
    private let logger = FerrousLogger.app

    /// Called when the application has finished launching
    func applicationDidFinishLaunching(_ notification: Notification) {
        FerrousLogger.shared.info("Application starting - version \(Constants.version)", log: logger)

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize configuration
        initializeConfiguration()

        // Start the background service with default intervals
        BackgroundService.shared.start()

        // Initialize the status bar controller
        statusBarController = StatusBarController()

        FerrousLogger.shared.info("Application startup complete", log: logger)
    }

    /// Called when the application will terminate
    func applicationWillTerminate(_ notification: Notification) {
        FerrousLogger.shared.info("Application shutting down", log: logger)

        // Stop the background service
        BackgroundService.shared.stop()

        FerrousLogger.shared.info("Application shutdown complete", log: logger)
    }

    /// Initializes the application configuration
    private func initializeConfiguration() {
        FerrousLogger.shared.debug("Initializing configuration", log: logger)

        _ = ConfigManager.shared.copyDefaultConfigFromBundle()

        // Load configuration
        let configLoaded = ConfigManager.shared.loadConfig()

        if !configLoaded {
            FerrousLogger.shared.warning("Failed to load configuration", log: logger)

            // Create default config
            let username = ProcessInfo.processInfo.environment["USER"] ?? "default-user"
            let organization = "motain"

            let config = ConfigManager.shared.createDefaultConfig(
                githubUser: username,
                githubOrg: organization
            )

            let saved = ConfigManager.shared.saveConfig(config)
            FerrousLogger.shared.debug("Created and saved default configuration: \(saved)", log: logger)
        } else {
            FerrousLogger.shared.debug("Configuration loaded successfully", log: logger)
        }
    }
}
