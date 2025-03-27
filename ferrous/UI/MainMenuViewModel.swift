import Foundation
import Combine

/// View model for the main menu view
final class MainMenuViewModel: ObservableObject {
    /// Shared instance
    static let shared = MainMenuViewModel()

    // MARK: - Published Properties

    /// The selected tab index
    @Published var selectedTab = 0

    /// GitHub pull requests
    @Published var pullRequests: [PullRequest] = []

    /// Whether GitHub PRs are being updated
    @Published var isLoadingPRs = false

    /// Tool statuses
    @Published var toolStatuses: [ToolStatus] = []

    /// Whether tool statuses are being updated
    @Published var isLoadingTools = false

    /// Local Kubernetes context
    @Published var localKubernetesContext: KubernetesContext?

    /// Remote/stable Kubernetes context
    @Published var remoteKubernetesContext: KubernetesContext?

    /// Whether Kubernetes contexts are being updated
    @Published var isLoadingKubernetes = false

    /// Whether an update is available
    @Published var updateAvailable = false

    /// URL to the latest release
    @Published var releaseURL: URL?

    /// Custom links from config
    @Published var customLinks: [CustomLink] = []

    /// Custom actions from config
    @Published var customActions: [CustomAction] = []
    
    /// The latest available version
    @Published var latestVersion: String?

    // MARK: - Private Properties

    /// Logger instance
    private let logger = FerrousLogger.app

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Private initializer to support singleton pattern
    private init() {
        FerrousLogger.shared.debug("Initializing MainMenuViewModel", log: logger)
        loadCustomData()
    }

    // MARK: - Public Methods

    /// Starts monitoring for updates
    func startMonitoring() {
        FerrousLogger.shared.debug("Starting monitoring in MainMenuViewModel", log: logger)

        // Subscribe to GitHub updates
        BackgroundService.shared.githubUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pullRequests in
                self?.pullRequests = pullRequests
                self?.isLoadingPRs = false
            }
            .store(in: &cancellables)

        // Subscribe to tool status updates
        BackgroundService.shared.toolStatusesUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] toolStatuses in
                self?.toolStatuses = toolStatuses
                self?.isLoadingTools = false
            }
            .store(in: &cancellables)

        // Subscribe to Kubernetes context updates
        BackgroundService.shared.kubernetesContextsUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contexts in
                self?.localKubernetesContext = contexts.local
                self?.remoteKubernetesContext = contexts.remote
                self?.isLoadingKubernetes = false
            }
            .store(in: &cancellables)

        // Subscribe to version updates
        BackgroundService.shared.versionUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] versionInfo in
                self?.updateAvailable = versionInfo.updateAvailable
                self?.releaseURL = versionInfo.releaseUrl
            }
            .store(in: &cancellables)
    }

    /// Stops monitoring for updates
    func stopMonitoring() {
        FerrousLogger.shared.debug("Stopping monitoring in MainMenuViewModel", log: logger)
        cancellables.removeAll()
    }

    /// Refreshes all data
    func refreshAll() {
        FerrousLogger.shared.debug("Manually refreshing all data in MainMenuViewModel", log: logger)

        isLoadingPRs = true
        isLoadingTools = true
        isLoadingKubernetes = true

        BackgroundService.shared.refreshAll()
    }

    /// Updates the refresh interval
    /// - Parameter interval: The new interval in seconds
    func updateRefreshInterval(_ interval: Double) {
        FerrousLogger.shared.debug("Updating refresh interval to \(interval) seconds", log: logger)
        BackgroundService.shared.updateRefreshIntervals(baseInterval: interval)

        // Save to user defaults
        UserDefaults.standard.set(interval, forKey: Constants.UserDefaultsKey.refreshInterval)
    }

    // MARK: - Private Methods

    /// Loads custom links and actions from config
    private func loadCustomData() {
        FerrousLogger.shared.debug("Loading custom data from config", log: logger)

        // Load links
        if let links = ConfigManager.shared.config?.tierZero?.links {
            customLinks = links.compactMap { $0.toDomainModel() }
            FerrousLogger.shared.debug("Loaded \(customLinks.count) custom links", log: logger)
        }

        // Load actions
        var actions: [CustomAction] = []
        if let actionsConfig = ConfigManager.shared.config?.actions {
            for (key, config) in actionsConfig {
                if let action = config.toDomainModel(key: key) {
                    actions.append(action)
                }
            }
            FerrousLogger.shared.debug("Loaded \(actions.count) custom actions", log: logger)
        }
        customActions = actions
    }
}
