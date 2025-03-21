import Foundation
import Security

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
        
        logger.debug("Loaded GitHub config - user: \(username), org: \(organization), repos: \(repositories.count)")
        isConfigured = true
    }
    
    /// Fetches pull requests from GitHub
    /// - Parameter completion: Callback with result containing pull requests or error
    func fetchPullRequests(completion: @escaping (Result<[PullRequest], Error>) -> Void) {
        // Make sure we're configured
        if !isConfigured {
            loadConfig()
            
            if !isConfigured {
                completion(.failure(GitHubError.notConfigured))
                return
            }
        }
        
        // Ensure we have a token
        guard let token = githubToken, !token.isEmpty else {
            logger.error("No GitHub token available")
            completion(.failure(GitHubError.noToken))
            return
        }
        
        // In a real implementation, this would make API calls to GitHub
        // For now just return an empty array, not mock data
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.logger.debug("Fetching pull requests")
            
            // This is where you would implement the actual GitHub API calls
            // For example:
            // - Fetch user pull requests
            // - Fetch repository pull requests
            // - Combine and return the results
            
            // For now, just return empty array
            DispatchQueue.main.async {
                completion(.success([]))
            }
        }
    }
    
    /// Loads the GitHub token from keychain, environment variable, or file
    private func loadToken() {
        // First try keychain
        if let keychainToken = loadTokenFromKeychain() {
            logger.debug("Using GitHub token from keychain")
            githubToken = keychainToken
            return
        }
        
        // Next try environment variables using all common formats
        let envVarNames = ["GITHUB_TOKEN", "GH_TOKEN", "GITHUB_API_TOKEN", "GH_API_TOKEN"]
        
        for varName in envVarNames {
            if let envToken = ProcessInfo.processInfo.environment[varName], !envToken.isEmpty {
                logger.debug("Using GitHub token from environment variable \(varName)")
                githubToken = envToken
                
                // Save to keychain for future use
                _ = saveTokenToKeychain(token: envToken)
                return
            }
        }
        
        // Try shell environment value via process
        if let shellToken = getTokenFromShellEnvironment() {
            logger.debug("Using GitHub token from shell environment")
            githubToken = shellToken
            
            // Save to keychain for future use
            _ = saveTokenToKeychain(token: shellToken)
            return
        }
        
        // Fallback to file
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        
        // Check common token file locations
        let tokenPaths = [
            homeDir.appendingPathComponent(".github_token"),
            homeDir.appendingPathComponent(".github/token"),
            homeDir.appendingPathComponent(".config/gh/token")
        ]
        
        for tokenPath in tokenPaths {
            if fileManager.fileExists(atPath: tokenPath.path) {
                do {
                    let token = try String(contentsOf: tokenPath, encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !token.isEmpty {
                        githubToken = token
                        logger.debug("Loaded GitHub token from file: \(tokenPath.path)")
                        
                        // Save to keychain for future use
                        _ = saveTokenToKeychain(token: token)
                        return
                    }
                } catch {
                    logger.error("Failed to load GitHub token from file \(tokenPath.path): \(error)")
                }
            }
        }
        
        // If we've got this far, no token was found
        logger.warning("No GitHub token found in keychain, environment variables, or files")
    }
    
    /// Loads the GitHub token from the Keychain
    /// - Returns: The token if found, nil otherwise
    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ferrous-github-token",
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        
        return token
    }
    
    /// Saves the GitHub token to the Keychain
    /// - Parameter token: The token to save
    /// - Returns: Whether the operation was successful
    @discardableResult
    private func saveTokenToKeychain(token: String) -> Bool {
        guard !token.isEmpty else { return false }
        
        // First, try to delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ferrous-github-token"
        ]
        
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Now add the new token
        let tokenData = token.data(using: .utf8)!
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ferrous-github-token",
            kSecValueData as String: tokenData
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        if status == errSecSuccess {
            logger.debug("Saved GitHub token to keychain")
            return true
        } else {
            logger.error("Failed to save GitHub token to keychain. Status: \(status)")
            return false
        }
    }
    
    /// Gets the GitHub token from shell environment by launching a subprocess
    /// - Returns: The token if found, nil otherwise
    private func getTokenFromShellEnvironment() -> String? {
        // Try to get token from common shell profile files by sourcing them
        let commands = [
            "source ~/.zshrc > /dev/null 2>&1 && echo $GITHUB_TOKEN",
            "source ~/.bashrc > /dev/null 2>&1 && echo $GITHUB_TOKEN",
            "source ~/.bash_profile > /dev/null 2>&1 && echo $GITHUB_TOKEN",
            "security find-generic-password -a ${USER} -s 'github-token' -w 2>/dev/null" // MacOS specific
        ]
        
        for command in commands {
            let (output, _, exitCode) = Process.shell(command)
            
            if exitCode == 0 {
                let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty {
                    return token
                }
            }
        }
        
        return nil
    }
}

// MARK: - GitHub Errors

extension GitHubService {
    /// Errors that can occur during GitHub operations
    enum GitHubError: Error, LocalizedError {
        case notConfigured
        case noToken
        case apiError(String)
        case parsingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "GitHub service is not configured"
            case .noToken:
                return "No GitHub API token available"
            case .apiError(let message):
                return "GitHub API error: \(message)"
            case .parsingError(let error):
                return "Error parsing GitHub response: \(error.localizedDescription)"
            }
        }
    }
}
