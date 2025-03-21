import Foundation
import Combine
import Logging

/// Manages all background tasks in the app, including scheduling and executing them.
final class BackgroundService {
    /// Shared instance
    static let shared = BackgroundService()

    // MARK: - Publishers

    /// Publisher for GitHub pull requests updates
    let githubUpdated = PassthroughSubject<[PullRequest], Never>()

    /// Publisher for tool status updates
    let toolStatusesUpdated = PassthroughSubject<[ToolStatus], Never>()

    /// Publisher for Kubernetes context updates
    let kubernetesContextsUpdated = PassthroughSubject<(local: KubernetesContext?, remote: KubernetesContext?), Never>()

    /// Publisher for version updates
    let versionUpdated = PassthroughSubject<(currentVersion: String, latestVersion: String, updateAvailable: Bool, releaseUrl: URL?), Never>()

    // MARK: - Status tracking

    /// Whether GitHub PRs are currently being updated
    private(set) var isUpdatingGitHub = false

    /// Whether tool statuses are currently being updated
    private(set) var isUpdatingTools = false

    /// Whether Kubernetes contexts are currently being updated
    private(set) var isUpdatingKubernetes = false

    /// Whether version info is currently being updated
    private(set) var isUpdatingVersion = false

    // MARK: - Private properties

    /// Main timer for scheduled tasks
    private var timer: DispatchSourceTimer?

    /// Queue for background operations
    private let backgroundQueue = DispatchQueue(label: "com.onefootball.ferrous.background", qos: .utility)

    /// Logger instance
    private let logger = FerrousLogger.app

    /// Refresh intervals
    private var githubRefreshInterval: TimeInterval = Constants.RefreshInterval.github
    private var toolsRefreshInterval: TimeInterval = Constants.RefreshInterval.tools
    private var kubernetesRefreshInterval: TimeInterval = Constants.RefreshInterval.kubernetes
    private var versionRefreshInterval: TimeInterval = Constants.RefreshInterval.version

    /// Default general refresh interval
    private var defaultRefreshInterval: TimeInterval = Constants.RefreshInterval.default

    /// Defines how long to wait to consider a task as timed out
    private let taskTimeoutInterval: TimeInterval = 10 // seconds

    /// Private init to enforce singleton
    private init() {}

    // MARK: - Public Methods

    /// Starts background tasks with the specified refresh interval
    /// - Parameter interval: The base refresh interval in seconds (all task-specific intervals are relative to this)
    func start(interval: TimeInterval = Constants.RefreshInterval.default) {
        stop() // Stop any existing timers

        logger.info("Starting background service with base interval \(interval) seconds")
        defaultRefreshInterval = interval

        // Configure task-specific intervals
        updateIntervals()

        // Initial update
        refreshAll()

        // Set up timer for regular updates
        timer = DispatchSource.makeTimerSource(queue: backgroundQueue)
        timer?.schedule(deadline: .now() + interval, repeating: interval)
        timer?.setEventHandler { [weak self] in
            self?.performScheduledUpdates()
        }
        timer?.resume()
    }

    /// Stops all background tasks
    func stop() {
        logger.info("Stopping background service")
        timer?.cancel()
        timer = nil
    }

    /// Updates the base refresh interval
    /// - Parameter interval: The new interval in seconds
    func updateRefreshInterval(_ interval: TimeInterval) {
        logger.debug("Updating refresh interval to \(interval) seconds")
        defaultRefreshInterval = max(10, interval)  // Minimum 10 seconds

        // Update task-specific intervals
        updateIntervals()

        // Restart the timer with the new interval
        if timer != nil {
            stop()
            start(interval: defaultRefreshInterval)
        }
    }

    /// Refreshes all tasks immediately
    func refreshAll() {
        logger.debug("Manually refreshing all tasks")
        backgroundQueue.async { [weak self] in
            self?.refreshGitHubPRs()
            self?.refreshToolStatuses()
            self?.refreshKubernetesContexts()
            self?.refreshVersionInfo()
        }
    }

    /// Updates GitHub pull requests
    func refreshGitHubPRs() {
        // Skip if already updating
        guard !isUpdatingGitHub else {
            logger.debug("Skipping GitHub update - already in progress")
            return
        }

        isUpdatingGitHub = true
        logger.debug("Refreshing GitHub pull requests")

        // This would call the GitHub service to fetch PRs
        // For now, just simulate with a delay
        backgroundQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Example PR data
            let examplePRs = [
                PullRequest(
                    id: 101,
                    title: "Add new feature",
                    repository: "onefootball/ferrous",
                    url: URL(string: "https://github.com/onefootball/ferrous/pull/101")!,
                    author: "user1",
                    createdAt: Date().addingTimeInterval(-86400), // 1 day ago
                    updatedAt: Date().addingTimeInterval(-3600),  // 1 hour ago
                    state: .open
                ),
                PullRequest(
                    id: 102,
                    title: "Fix bug in tool checker",
                    repository: "onefootball/ferrous",
                    url: URL(string: "https://github.com/onefootball/ferrous/pull/102")!,
                    author: "user2",
                    createdAt: Date().addingTimeInterval(-43200), // 12 hours ago
                    updatedAt: Date().addingTimeInterval(-1800),  // 30 mins ago
                    state: .open
                )
            ]

            // Send update to listeners
            DispatchQueue.main.async {
                self.githubUpdated.send(examplePRs)
                self.isUpdatingGitHub = false
                self.logger.debug("GitHub pull requests updated")
            }
        }
    }

    /// Updates tool statuses
    func refreshToolStatuses() {
        // Skip if already updating
        guard !isUpdatingTools else {
            logger.debug("Skipping tools update - already in progress")
            return
        }

        isUpdatingTools = true
        logger.debug("Refreshing tool statuses")

        // This would call the tool check service to check tools
        // For now, just simulate with a delay
        backgroundQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Example tool statuses
            let exampleToolStatuses = [
                ToolStatus(
                    id: "kubectl",
                    name: "kubectl",
                    isAvailable: true,
                    helpText: "Check kubectl status",
                    lastChecked: Date(),
                    checkCommand: "which kubectl"
                ),
                ToolStatus(
                    id: "helm",
                    name: "helm",
                    isAvailable: true,
                    helpText: "Check helm status",
                    lastChecked: Date(),
                    checkCommand: "which helm"
                ),
                ToolStatus(
                    id: "vpn",
                    name: "vpn",
                    isAvailable: false,
                    helpText: "Check VPN status",
                    lastChecked: Date(),
                    checkCommand: "ping -c 1 10.0.0.1",
                    errorMessage: "Network unreachable"
                )
            ]

            // Send update to listeners
            DispatchQueue.main.async {
                self.toolStatusesUpdated.send(exampleToolStatuses)
                self.isUpdatingTools = false
                self.logger.debug("Tool statuses updated")
            }
        }
    }

    /// Updates Kubernetes contexts
    func refreshKubernetesContexts() {
        // Skip if already updating
        guard !isUpdatingKubernetes else {
            logger.debug("Skipping Kubernetes update - already in progress")
            return
        }

        isUpdatingKubernetes = true
        logger.debug("Refreshing Kubernetes contexts")

        // This would call the Kubernetes service to check contexts
        // For now, just simulate with a delay
        backgroundQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Example contexts
            let localContext = KubernetesContext(
                name: "docker-desktop",
                cluster: "docker-desktop",
                isActive: true,
                isStable: false
            )

            let remoteContext = KubernetesContext(
                name: "eks-production",
                cluster: "arn:aws:eks:eu-west-1:123456789012:cluster/eks-production",
                isActive: false,
                isStable: true
            )

            // Send update to listeners
            DispatchQueue.main.async {
                self.kubernetesContextsUpdated.send((local: localContext, remote: remoteContext))
                self.isUpdatingKubernetes = false
                self.logger.debug("Kubernetes contexts updated")
            }
        }
    }

    /// Updates version information
    func refreshVersionInfo() {
        // Skip if already updating
        guard !isUpdatingVersion else {
            logger.debug("Skipping version update - already in progress")
            return
        }

        isUpdatingVersion = true
        logger.debug("Refreshing version information")

        // This would call the version service to check for updates
        // For now, just simulate with a delay
        backgroundQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Example version info
            let currentVersion = Constants.version
            let latestVersion = "1.1.0"  // Simulated newer version
            let updateAvailable = currentVersion != latestVersion
            let releaseUrl = URL(string: "https://github.com/onefootball/ferrous/releases/latest")

            // Send update to listeners
            DispatchQueue.main.async {
                self.versionUpdated.send((
                    currentVersion: currentVersion,
                    latestVersion: latestVersion,
                    updateAvailable: updateAvailable,
                    releaseUrl: releaseUrl
                ))
                self.isUpdatingVersion = false
                self.logger.debug("Version information updated")
            }
        }
    }

    // MARK: - Private Methods

    /// Updates task-specific intervals based on the default interval
    private func updateIntervals() {
        // GitHub: 5 times the default interval
        githubRefreshInterval = defaultRefreshInterval * 5

        // Tools: Same as default
        toolsRefreshInterval = defaultRefreshInterval

        // Kubernetes: 3 times the default interval
        kubernetesRefreshInterval = defaultRefreshInterval * 3

        // Version: 30 times the default interval (less frequent)
        versionRefreshInterval = defaultRefreshInterval * 30

        logger.debug("Updated refresh intervals - GitHub: \(githubRefreshInterval)s, Tools: \(toolsRefreshInterval)s, Kubernetes: \(kubernetesRefreshInterval)s, Version: \(versionRefreshInterval)s")
    }

    /// Performs scheduled updates based on elapsed time
    private func performScheduledUpdates() {
        let now = Date().timeIntervalSince1970
        let defaults = UserDefaults.standard

        // Check each service's last update time
        let lastGitHubUpdate = defaults.double(forKey: Constants.UserDefaultsKey.lastGitHubUpdate)
        let lastToolsUpdate = defaults.double(forKey: Constants.UserDefaultsKey.lastToolsUpdate)
        let lastKubernetesUpdate = defaults.double(forKey: Constants.UserDefaultsKey.lastKubernetesUpdate)
        let lastVersionUpdate = defaults.double(forKey: Constants.UserDefaultsKey.lastVersionUpdate)

        // Update each service if enough time has elapsed
        if now - lastGitHubUpdate >= githubRefreshInterval {
            logger.debug("Scheduled GitHub update triggered (elapsed: \(now - lastGitHubUpdate)s)")
            refreshGitHubPRs()
            defaults.set(now, forKey: Constants.UserDefaultsKey.lastGitHubUpdate)
        }

        if now - lastToolsUpdate >= toolsRefreshInterval {
            logger.debug("Scheduled tools update triggered (elapsed: \(now - lastToolsUpdate)s)")
            refreshToolStatuses()
            defaults.set(now, forKey: Constants.UserDefaultsKey.lastToolsUpdate)
        }

        if now - lastKubernetesUpdate >= kubernetesRefreshInterval {
            logger.debug("Scheduled Kubernetes update triggered (elapsed: \(now - lastKubernetesUpdate)s)")
            refreshKubernetesContexts()
            defaults.set(now, forKey: Constants.UserDefaultsKey.lastKubernetesUpdate)
        }

        if now - lastVersionUpdate >= versionRefreshInterval {
            logger.debug("Scheduled version update triggered (elapsed: \(now - lastVersionUpdate)s)")
            refreshVersionInfo()
            defaults.set(now, forKey: Constants.UserDefaultsKey.lastVersionUpdate)
        }
    }
}