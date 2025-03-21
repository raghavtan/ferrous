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

        // Initialize configuration and start background service when ready
        initializeConfiguration()

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

        // Check if config exists and has valid GitHub user/org information
        let placeholderValues = ["placeholder", "dummy", "default-user", "your-username", "your-organisation", "change-me", ""]
        let needsUserInput: Bool
        
        if !configLoaded {
            logger.warning("Failed to load configuration, will create a new one with user input")
            needsUserInput = true
        } else if let githubConfig = ConfigManager.shared.config?.tierZero?.github {
            // Check if GitHub username or organization is empty or has placeholder values
            let hasValidUsername = !placeholderValues.contains(githubConfig.user.lowercased())
            let hasValidOrg = !placeholderValues.contains(githubConfig.organisation.lowercased())
            
            needsUserInput = !hasValidUsername || !hasValidOrg
            
            if needsUserInput {
                logger.warning("GitHub configuration has placeholder or empty values, requesting user input")
            }
        } else {
            logger.warning("GitHub configuration section is missing, requesting user input")
            needsUserInput = true
        }
        
        if needsUserInput {
            // Show popup to get GitHub information
            DispatchQueue.main.async {
                self.showGitHubConfigPopup()
            }
        } else {
            // Configuration is valid, start services
            logger.debug("Configuration loaded successfully")
            startBackgroundService()
            
            // Initialize the status bar controller
            statusBarController = StatusBarController()
        }
    }
    
    /// Shows a popup to get GitHub user and organization information
    func showGitHubConfigPopup() {
            let alert = NSAlert()
            alert.messageText = "GitHub Configuration Required"
            alert.informativeText = "Please enter your GitHub username and organization to continue."
            alert.alertStyle = .informational
            
            // Create a container with proper spacing
            let containerWidth: CGFloat = 300
            let containerHeight: CGFloat = 120
            let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
            
            // Label styling
            let labelWidth: CGFloat = 140
            let labelHeight: CGFloat = 20
            let labelFont = NSFont.systemFont(ofSize: 13)
            
            // Text field styling
            let fieldX: CGFloat = labelWidth + 10
            let fieldWidth: CGFloat = containerWidth - fieldX - 10
            let fieldHeight: CGFloat = 24
            
            // Row positioning
            let row1Y: CGFloat = containerHeight - labelHeight - 10
            let row2Y: CGFloat = row1Y - fieldHeight - 15
            
            // Create username label and field
            let usernameLabel = NSTextField(labelWithString: "GitHub Username:")
            usernameLabel.frame = NSRect(x: 0, y: row1Y, width: labelWidth, height: labelHeight)
            usernameLabel.alignment = .right
            usernameLabel.font = labelFont
            
            let usernameField = NSTextField(frame: NSRect(x: fieldX, y: row1Y - 3, width: fieldWidth, height: fieldHeight))
            usernameField.placeholderString = "Your GitHub username"
            
            // Create organization label and field
            let orgLabel = NSTextField(labelWithString: "GitHub Organization:")
            orgLabel.frame = NSRect(x: 0, y: row2Y, width: labelWidth, height: labelHeight)
            orgLabel.alignment = .right
            orgLabel.font = labelFont
            
            let orgField = NSTextField(frame: NSRect(x: fieldX, y: row2Y - 3, width: fieldWidth, height: fieldHeight))
            orgField.placeholderString = "Your organization"
            
            // Pre-fill with existing values if available
            if let gitConfig = ConfigManager.shared.config?.tierZero?.github {
                usernameField.stringValue = gitConfig.user
                orgField.stringValue = gitConfig.organisation
            } else {
                // Default values
                usernameField.stringValue = ProcessInfo.processInfo.environment["USER"] ?? ""
                orgField.stringValue = "onefootball"
            }
            
            // Add controls to container
            container.addSubview(usernameLabel)
            container.addSubview(usernameField)
            container.addSubview(orgLabel)
            container.addSubview(orgField)
            
            alert.accessoryView = container
            
            // Customize the buttons
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            // Set initial focus to username field
            alert.window.initialFirstResponder = usernameField
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let organization = orgField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate input
                if username.isEmpty || organization.isEmpty {
                    // Show error and try again
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Invalid Input"
                    errorAlert.informativeText = "Username and organization cannot be empty."
                    errorAlert.alertStyle = .critical
                    errorAlert.runModal()
                    
                    // Try again
                    DispatchQueue.main.async {
                        self.showGitHubConfigPopup()
                    }
                    return
                }
                
                // Save the configuration
                saveGitHubConfig(username: username, organization: organization)
            } else {
                // User canceled, exit the app
                logger.warning("User canceled GitHub configuration, exiting application")
                NSApplication.shared.terminate(nil)
            }
        }
    
    /// Saves the GitHub configuration and continues app initialization
    private func saveGitHubConfig(username: String, organization: String) {
        // Create or update the configuration
        let config: AppConfig
        
        if let existingConfig = ConfigManager.shared.config {
            // Update existing config
            var updatedConfig = existingConfig
            
            // Create GitHub config if it doesn't exist
            if updatedConfig.tierZero == nil {
                updatedConfig.tierZero = TierZeroConfig(
                    github: GitHubConfig(
                        user: username,
                        organisation: organization,
                        timezone: "Europe/Berlin",
                        repositories: ["\(organization)/ferrous"]
                    ),
                    links: []
                )
            } else if updatedConfig.tierZero?.github == nil {
                updatedConfig.tierZero?.github = GitHubConfig(
                    user: username,
                    organisation: organization,
                    timezone: "Europe/Berlin",
                    repositories: ["\(organization)/ferrous"]
                )
            } else {
                // Update existing GitHub config
                updatedConfig.tierZero?.github.user = username
                updatedConfig.tierZero?.github.organisation = organization
                // Update repositories if they're based on the organization
                if let repos = updatedConfig.tierZero?.github.repositories,
                   !repos.isEmpty,
                   repos[0].contains("/") {
                    let repoName = repos[0].split(separator: "/").last ?? "ferrous"
                    updatedConfig.tierZero?.github.repositories = ["\(organization)/\(repoName)"]
                }
            }
            
            config = updatedConfig
        } else {
            // Create new default config with the provided values
            config = ConfigManager.shared.createDefaultConfig(
                githubUser: username,
                githubOrg: organization
            )
        }
        
        // Save the updated config
        let saved = ConfigManager.shared.saveConfig(config)
        logger.debug("Config saved: \(saved)")
        
        // Continue with app initialization
        startBackgroundService()
        
        // Initialize the status bar controller
        statusBarController = StatusBarController()
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
