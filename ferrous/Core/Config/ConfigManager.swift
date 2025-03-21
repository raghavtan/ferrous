import Foundation
import Yams
import Logging

/// Manages the app configuration, including loading from and saving to disk.
final class ConfigManager {
    /// Shared instance
    static let shared = ConfigManager()

    /// The current configuration
    private(set) var config: AppConfig?

    /// Logger instance
    private let logger = FerrousLogger.app

    /// File manager for disk operations
    private let fileManager = FileManager.default

    /// Creates a new instance
    private init() {}

    /// Loads configuration from disk
    /// - Returns: `true` if successful, `false` otherwise
    @discardableResult
    func loadConfig() -> Bool {
        FerrousLogger.shared.debug("Loading configuration from \(Constants.Path.configFile.path)", log: logger)

        do {
            // Check if config directory exists, create it if needed
            try fileManager.ensureDirectoryExists(at: Constants.Path.configDir)

            // Check if config file exists
            if fileManager.fileExists(atPath: Constants.Path.configFile.path) {
                let configData = try Data(contentsOf: Constants.Path.configFile)
                guard let configString = String(data: configData, encoding: .utf8) else {
                    FerrousLogger.shared.error("Failed to decode config data as UTF-8", log: logger)
                    return false
                }

                // Parse YAML
                config = try YAMLDecoder().decode(AppConfig.self, from: configString)
                FerrousLogger.shared.debug("Configuration loaded successfully", log: logger)
                return true
            } else {
                FerrousLogger.shared.warning("Config file does not exist at \(Constants.Path.configFile.path)", log: logger)
                return false
            }
        } catch {
            FerrousLogger.shared.error("Error loading config: \(error)", log: logger)
            return false
        }
    }

    /// Saves configuration to disk
    /// - Parameter config: The configuration to save
    /// - Returns: `true` if successful, `false` otherwise
    @discardableResult
    func saveConfig(_ config: AppConfig) -> Bool {
        FerrousLogger.shared.debug("Saving configuration to \(Constants.Path.configFile.path)", log: logger)

        do {
            // Check if config directory exists, create it if needed
            try fileManager.ensureDirectoryExists(at: Constants.Path.configDir)

            // Encode to YAML
            let yamlString = try YAMLEncoder().encode(config)

            // Write to file
            try yamlString.write(to: Constants.Path.configFile, atomically: true, encoding: .utf8)

            // Update in-memory config
            self.config = config

            // Notify listeners
            NotificationCenter.default.post(name: Constants.NotificationName.configurationUpdated, object: nil)

            FerrousLogger.shared.debug("Configuration saved successfully", log: logger)
            return true
        } catch {
            FerrousLogger.shared.error("Error saving config: \(error)", log: logger)
            return false
        }
    }

    /// Creates a default configuration
    /// - Parameters:
    ///   - githubUser: GitHub username
    ///   - githubOrg: GitHub organization
    /// - Returns: A default configuration
    func createDefaultConfig(githubUser: String, githubOrg: String) -> AppConfig {
        FerrousLogger.shared.debug("Creating default configuration for user \(githubUser), org \(githubOrg)", log: logger)

        // Create GitHub config
        let githubConfig = GitHubConfig(
            user: githubUser,
            organisation: githubOrg,
            timezone: "Europe/Berlin",
            repositories: ["\(githubOrg)/ferrous"]
        )

        // Create Tier Zero config with GitHub and links
        let tierZeroConfig = TierZeroConfig(
            github: githubConfig,
            links: [
                CustomLinkConfig(name: "Trusted Advisor", url: "https://us-east-1.console.aws.amazon.com/trustedadvisor/home"),
                CustomLinkConfig(name: "AWS Health Dashboard", url: "https://health.console.aws.amazon.com/health/home")
            ]
        )

        // Create tool configurations
        var toolConfigs = [String: ToolConfig]()
        toolConfigs["kubectl"] = ToolConfig(
            title: "kubectl",
            help: "Check kubectl status",
            checkCommand: "which kubectl"
        )
        toolConfigs["helm"] = ToolConfig(
            title: "helm",
            help: "Check helm status",
            checkCommand: "which helm"
        )
        toolConfigs["vpn"] = ToolConfig(
            title: "vpn",
            help: "Check VPN status",
            checkCommand: "ping -c 1 10.0.0.1"
        )
        toolConfigs["aws"] = ToolConfig(
            title: "aws-cli",
            help: "Check AWS CLI status",
            checkCommand: "which aws"
        )
        toolConfigs["git"] = ToolConfig(
            title: "git",
            help: "Check Git status",
            checkCommand: "which git"
        )

        let checkerConfig = CheckerConfig(tools: toolConfigs)

        // Create custom actions
               var actions = [String: CustomActionConfig]()
               actions["jumpcloud"] = CustomActionConfig(
                   title: "JumpCloud",
                   help: "Open JumpCloud",
                   type: "url",
                   url: "https://console.jumpcloud.com/userconsole#/"
               )

               actions["itsupport"] = CustomActionConfig(
                   title: "IT Support",
                   help: "Open IT Support",
                   type: "url",
                   url: "https://onefootball.atlassian.net/servicedesk/customer/portal/1"
               )

               actions["saml"] = CustomActionConfig(
                   title: "SAML Profiles",
                   help: "List of SAML Profiles",
                   type: "dynamicDropdown",
                   file: "~/.saml2aws",
                   jsonPathExpressions: "$..name",
                   parser: "toml"
               )

               return AppConfig(
                   tierZero: tierZeroConfig,
                   checker: checkerConfig,
                   actions: actions
               )
    }

    /// Copies the default configuration file from the bundle if it exists
    /// - Returns: `true` if successful, `false` otherwise
    @discardableResult
    func copyDefaultConfigFromBundle() -> Bool {
        FerrousLogger.shared.debug("Looking for default config in app bundle", log: logger)

        // Skip if config file already exists
        if fileManager.fileExists(atPath: Constants.Path.configFile.path) {
            FerrousLogger.shared.debug("Config file already exists, skipping copy", log: logger)
            return true
        }

        // Look for default.yaml in the main bundle
        guard let bundlePath = Bundle.main.path(forResource: "default", ofType: "yaml") else {
            FerrousLogger.shared.warning("Default config not found in bundle", log: logger)
            return false
        }

        do {
            // Ensure config directory exists
            try fileManager.ensureDirectoryExists(at: Constants.Path.configDir)

            // Copy file
            try fileManager.copyItem(atPath: bundlePath, toPath: Constants.Path.configFile.path)
            FerrousLogger.shared.info("Default config copied from bundle", log: logger)
            return true
        } catch {
            FerrousLogger.shared.error("Failed to copy default config: \(error)", log: logger)
            return false
        }
    }
}
