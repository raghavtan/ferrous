import Foundation

/// Service for interacting with GitHub, including retrieving pull requests.
final class GitHubService {
    /// Shared instance
    static let shared = GitHubService()
    
    /// Logger instance
    private let logger = FerrousLogger.github
    
    /// The GitHub API token for authentication
    private var githubToken: String?
    
    /// GitHub username from config
    private var username: String = ""
    
    /// GitHub organization from config
    private var organization: String = ""
    
    /// Repositories to monitor
    private var repositories: [String] = []
    
    /// Indicates if the service is initialized with valid configuration
    private(set) var isConfigured = false
    
    /// URL session for network requests
    private let session: URLSession
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Configure URL session for GitHub API requests
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        session = URLSession(configuration: config)
        
        // Load token from environment or file
        loadToken()
        
        // Load config if available
        loadConfig()
    }
    
    /// Loads configuration from ConfigManager
    func loadConfig() {
        guard let config = ConfigManager.shared.config?.tierZero?.github else {
            logger.warning("No GitHub configuration found")
            isConfigured = false
            return
        }
        
        username = config.user
        organization = config.organisation
        repositories = config.repositories
        
        logger.info("Loaded GitHub config - user: \(username), org: \(organization), repos: \(repositories.count)")
        isConfigured = true
    }
    
    /// Loads the GitHub token from environment or file
    private func loadToken() {
        // First try environment variable
        if let envToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            logger.info("Using GitHub token from environment variable")
            githubToken = envToken
            return
        }
        
        // Fallback to file
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let tokenPath = homeDir.appendingPathComponent(".github_token")
        
        if fileManager.fileExists(atPath: tokenPath.path) {
            do {
                githubToken = try String(contentsOf: tokenPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug("Loaded GitHub token from file")
            } catch {
                logger.error("Failed to load GitHub token from file: \(error)")
            }
        }
    }
}
