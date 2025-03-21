import Foundation
import Combine

/// Manages all background tasks in the app with simplified architecture
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
    
    // MARK: - Private properties
    
    /// Timers for each service
    private var githubTimer: Timer?
    private var toolsTimer: Timer?
    private var kubernetesTimer: Timer?
    private var versionTimer: Timer?
    
    /// Refresh intervals
    private var githubRefreshInterval: TimeInterval = Constants.RefreshInterval.github
    private var toolsRefreshInterval: TimeInterval = Constants.RefreshInterval.tools
    private var kubernetesRefreshInterval: TimeInterval = Constants.RefreshInterval.kubernetes
    private var versionRefreshInterval: TimeInterval = Constants.RefreshInterval.version
    
    /// Logger instance
    private let logger = FerrousLogger.app
    
    /// Private init to enforce singleton
    private init() {}
    
    // MARK: - Public Methods
    
    /// Starts all background tasks with their respective intervals
    func start() {
        stop() // Stop any existing timers
        
        FerrousLogger.shared.info("Starting background services", log: logger)
        
        // Start GitHub service
        startGitHubTimer()
        
        // Start Tools service
        startToolsTimer()
        
        // Start Kubernetes service
        startKubernetesTimer()
        
        // Start Version service
        startVersionTimer()
        
        // Initial update
        refreshAll()
    }
    
    /// Stops all background tasks
    func stop() {
        FerrousLogger.shared.info("Stopping all background services", log: logger)
        
        githubTimer?.invalidate()
        toolsTimer?.invalidate()
        kubernetesTimer?.invalidate()
        versionTimer?.invalidate()
        
        githubTimer = nil
        toolsTimer = nil
        kubernetesTimer = nil
        versionTimer = nil
    }
    
    /// Updates the refresh intervals based on the provided base interval
    /// - Parameter baseInterval: The base interval in seconds
    func updateRefreshIntervals(baseInterval: TimeInterval) {
        let interval = max(10, baseInterval) // Minimum 10 seconds
        
        // Update intervals (maintain the ratios from Constants)
        githubRefreshInterval = interval * 5    // 5x base interval
        toolsRefreshInterval = interval         // 1x base interval
        kubernetesRefreshInterval = interval * 3 // 3x base interval
        versionRefreshInterval = interval * 30   // 30x base interval
        
        FerrousLogger.shared.debug("Updated refresh intervals - GitHub: \(githubRefreshInterval)s, Tools: \(toolsRefreshInterval)s, Kubernetes: \(kubernetesRefreshInterval)s, Version: \(versionRefreshInterval)s", log: logger)
        
        // Restart timers with new intervals
        if githubTimer != nil || toolsTimer != nil || kubernetesTimer != nil || versionTimer != nil {
            stop()
            start()
        }
    }
    
    /// Refreshes all data immediately
    func refreshAll() {
        FerrousLogger.shared.debug("Manually refreshing all services", log: logger)
        refreshGitHubPRs()
        refreshToolStatuses()
        refreshKubernetesContexts()
        refreshVersionInfo()
    }
    
    /// Updates GitHub pull requests
    func refreshGitHubPRs() {
        FerrousLogger.shared.debug("Refreshing GitHub pull requests", log: logger)
        
        // Use the GitHub service to fetch real PRs
        // This is where you would call your actual GitHub service to fetch data
        GitHubService.shared.fetchPullRequests { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let pullRequests):
                DispatchQueue.main.async {
                    self.githubUpdated.send(pullRequests)
                    FerrousLogger.shared.debug("GitHub pull requests updated successfully", log: self.logger)
                }
            case .failure(let error):
                FerrousLogger.shared.error("Failed to refresh GitHub pull requests: \(error)", log: self.logger)
                DispatchQueue.main.async {
                    self.githubUpdated.send([]) // Send empty array on failure
                }
            }
        }
    }
    
    /// Updates tool statuses
    func refreshToolStatuses() {
        FerrousLogger.shared.debug("Refreshing tool statuses", log: logger)
        
        // Use the tool check service to check status of all tools
        ToolCheckService.shared.checkAllTools { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let toolStatuses):
                DispatchQueue.main.async {
                    self.toolStatusesUpdated.send(toolStatuses)
                    FerrousLogger.shared.debug("Tool statuses updated successfully", log: self.logger)
                }
            case .failure(let error):
                FerrousLogger.shared.error("Failed to refresh tool statuses: \(error)", log: self.logger)
                DispatchQueue.main.async {
                    self.toolStatusesUpdated.send([]) // Send empty array on failure
                }
            }
        }
    }
    
    /// Updates Kubernetes contexts
    func refreshKubernetesContexts() {
        FerrousLogger.shared.debug("Refreshing Kubernetes contexts", log: logger)
        
        // Use the Kubernetes service to fetch contexts
        KubernetesService.shared.refreshContexts { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.kubernetesContextsUpdated.send((
                        local: KubernetesService.shared.localContext,
                        remote: KubernetesService.shared.stableContext
                    ))
                    FerrousLogger.shared.debug("Kubernetes contexts updated successfully", log: self.logger)
                }
            case .failure(let error):
                FerrousLogger.shared.error("Failed to refresh Kubernetes contexts: \(error)", log: self.logger)
                DispatchQueue.main.async {
                    self.kubernetesContextsUpdated.send((local: nil, remote: nil))
                }
            }
        }
    }
    
    /// Updates version information
    func refreshVersionInfo() {
        FerrousLogger.shared.debug("Refreshing version information", log: logger)
        
        // Use the version service to check for updates
        VersionService.shared.checkForUpdates { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let updateAvailable):
                DispatchQueue.main.async {
                    self.versionUpdated.send((
                        currentVersion: VersionService.shared.currentVersion,
                        latestVersion: VersionService.shared.latestVersion ?? "Unknown",
                        updateAvailable: updateAvailable,
                        releaseUrl: VersionService.shared.releaseURL
                    ))
                    FerrousLogger.shared.debug("Version information updated successfully", log: self.logger)
                }
            case .failure(let error):
                FerrousLogger.shared.error("Failed to refresh version information: \(error)", log: self.logger)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Starts the GitHub refresh timer
    private func startGitHubTimer() {
        githubTimer = Timer.scheduledTimer(
            withTimeInterval: githubRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshGitHubPRs()
        }
    }
    
    /// Starts the tools refresh timer
    private func startToolsTimer() {
        toolsTimer = Timer.scheduledTimer(
            withTimeInterval: toolsRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshToolStatuses()
        }
    }
    
    /// Starts the Kubernetes refresh timer
    private func startKubernetesTimer() {
        kubernetesTimer = Timer.scheduledTimer(
            withTimeInterval: kubernetesRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshKubernetesContexts()
        }
    }
    
    /// Starts the version refresh timer
    private func startVersionTimer() {
        versionTimer = Timer.scheduledTimer(
            withTimeInterval: versionRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshVersionInfo()
        }
    }
}
