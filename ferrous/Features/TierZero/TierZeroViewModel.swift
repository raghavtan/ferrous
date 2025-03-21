import Foundation
import Combine

/// View model for the Tier Zero view
final class TierZeroViewModel: ObservableObject {
    /// Pull requests authored by the user
    @Published var userPullRequests: [PullRequest] = []

    /// Pull requests from monitored repositories
    @Published var repoPullRequests: [PullRequest] = []

    /// Whether data is being loaded
    @Published var isLoading = false

    /// Logger instance
    private let logger = FerrousLogger.github

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// GitHub username from config
    private var username: String = ""

    /// Monitored repositories from config
    private var repositories: [String] = []

    /// Initializes the view model
    init() {
        // Load config values
        loadConfig()

        // Subscribe to pull request updates from BackgroundService
        BackgroundService.shared.githubUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pullRequests in
                self?.processPullRequests(pullRequests)
                self?.isLoading = false
            }
            .store(in: &cancellables)

        // Also subscribe to MainMenuViewModel for initial values
        MainMenuViewModel.shared.$pullRequests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pullRequests in
                self?.processPullRequests(pullRequests)
            }
            .store(in: &cancellables)
    }

    /// Loads configuration
    private func loadConfig() {
        if let config = ConfigManager.shared.config?.tierZero?.github {
            username = config.user
            repositories = config.repositories
            FerrousLogger.shared.debug("Loaded config - username: \(username), repos: \(repositories.count)", log: logger)
        } else {
            FerrousLogger.shared.warning("No GitHub configuration found", log: logger)
        }
    }

    /// Processes pull requests to separate user PRs from repo PRs
    /// - Parameter pullRequests: The pull requests to process
    private func processPullRequests(_ pullRequests: [PullRequest]) {
        // Make sure we have config
        if username.isEmpty || repositories.isEmpty {
            loadConfig()
        }

        // Separate user PRs from repo PRs
        var userPRs = [PullRequest]()
        var repoPRs = [PullRequest]()

        for pr in pullRequests {
            // Check if this PR is authored by the user
            if pr.isAuthoredBy(user: username) {
                userPRs.append(pr)
                continue
            }

            // Check if this PR belongs to a monitored repository
            for repo in repositories {
                if pr.repository.lowercased() == repo.lowercased() {
                    repoPRs.append(pr)
                    break
                }
            }
        }

        // Sort PRs by update time (newest first)
        userPRs.sort { $0.updatedAt > $1.updatedAt }
        repoPRs.sort { $0.updatedAt > $1.updatedAt }

        // Update published properties
        self.userPullRequests = userPRs
        self.repoPullRequests = repoPRs

        FerrousLogger.shared.debug("Processed \(pullRequests.count) pull requests - user: \(userPRs.count), repo: \(repoPRs.count)", log: logger)
    }

    /// Loads pull requests from GitHub
    func loadPullRequests() {
        isLoading = true

        // If we already have data, show it while loading
        if userPullRequests.isEmpty && repoPullRequests.isEmpty {
            FerrousLogger.shared.debug("Triggering pull request refresh", log: logger)
            BackgroundService.shared.refreshGitHubPRs()
        } else {
            // Start a timer to set isLoading back to false if it takes too long
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isLoading = false
            }
        }
    }
}