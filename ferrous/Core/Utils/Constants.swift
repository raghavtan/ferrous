import Foundation

/// App-wide constants for Ferrous.
enum Constants {
    /// Bundle identification
    static let bundleId = Bundle.main.bundleIdentifier ?? "com.onefootball.ferrous"

    /// Current version of the app
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    /// Current build number
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    /// Refresh intervals for different services
    enum RefreshInterval {
        /// GitHub pull requests check interval (5 minutes)
        static let github: TimeInterval = 10

        /// Tool status check interval (1 minute)
        static let tools: TimeInterval = 6000

        /// Kubernetes context check interval (5 minutes)
        static let kubernetes: TimeInterval = 30000

        /// Version check interval (1 hour)
        static let version: TimeInterval = 2000

        /// Default interval when nothing specified
        static let `default`: TimeInterval = 6000
    }

    /// File paths for various resources
    enum Path {
        /// Default config directory (~/.ferrous)
        static let configDir: URL = {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            return homeDir.appendingPathComponent(".ferrous")
        }()

        /// Config file path
        static let configFile: URL = {
            return configDir.appendingPathComponent("config.yaml")
        }()

        /// Kube config file path
        static let kubeConfig: URL = {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            return homeDir.appendingPathComponent(".kube/config")
        }()
    }

    /// Notification names used throughout the app
    enum NotificationName {
        /// Environment variables updated
        static let environmentVariablesUpdated = Notification.Name("com.onefootball.ferrous.environmentVariablesUpdated")

        /// Configuration updated
        static let configurationUpdated = Notification.Name("com.onefootball.ferrous.configurationUpdated")

        /// GitHub pull requests updated
        static let githubPullRequestsUpdated = Notification.Name("com.onefootball.ferrous.githubPullRequestsUpdated")

        /// Tool statuses updated
        static let toolStatusesUpdated = Notification.Name("com.onefootball.ferrous.toolStatusesUpdated")

        /// Kubernetes context updated
        static let kubernetesContextUpdated = Notification.Name("com.onefootball.ferrous.kubernetesContextUpdated")

        /// Version information updated
        static let versionUpdated = Notification.Name("com.onefootball.ferrous.versionUpdated")
    }

    /// UserDefaults keys
    enum UserDefaultsKey {
        /// Last update time for GitHub
        static let lastGitHubUpdate = "lastGitHubUpdate"

        /// Last update time for tools
        static let lastToolsUpdate = "lastToolsUpdate"

        /// Last update time for Kubernetes
        static let lastKubernetesUpdate = "lastKubernetesUpdate"

        /// Last update time for version check
        static let lastVersionUpdate = "lastVersionUpdate"

        /// Refresh interval
        static let refreshInterval = "refreshInterval"
    }
}
