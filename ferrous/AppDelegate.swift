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
        logger.info("Application starting - version \(Constants.version)")

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize configuration
        initializeConfiguration()

        // Start the background service
        startBackgroundService()

        // Initialize the status bar controller
        statusBarController = StatusBarController()

        logger.info("Application startup complete")
    }

    /// Called when the application will terminate
    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application shutting down")

        // Stop the background service
        BackgroundService.shared.stop()

        logger.info("Application shutdown complete")
    }

    /// Initializes the application configuration
    private func initializeConfiguration() {
        logger.debug("Initializing configuration")

        _ = ConfigManager.shared.copyDefaultConfigFromBundle()

        // Load configuration
        let configLoaded = ConfigManager.shared.loadConfig()

        if !configLoaded {
            logger.warning("Failed to load configuration")

            // Create default config
            let username = ProcessInfo.processInfo.environment["USER"] ?? "default-user"
            let organization = "onefootball"

            let config = ConfigManager.shared.createDefaultConfig(
                githubUser: username,
                githubOrg: organization
            )

            let saved = ConfigManager.shared.saveConfig(config)
            logger.debug("Created and saved default configuration: \(saved)")
        } else {
            logger.debug("Configuration loaded successfully")
        }
    }

    /// Starts the background service
    private func startBackgroundService() {
        logger.debug("Starting background service")

        // Get refresh interval from UserDefaults or use default
        let refreshInterval = UserDefaults.standard.double(forKey: Constants.UserDefaultsKey.refreshInterval)
        let interval = refreshInterval > 0 ? refreshInterval : Constants.RefreshInterval.default

        // Start the service
        BackgroundService.shared.start(interval: interval)

        logger.debug("Background service started with interval \(interval) seconds")
    }
}
