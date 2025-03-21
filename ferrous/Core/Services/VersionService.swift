import Foundation
import Security

/// Service for checking app version and available updates.
final class VersionService {
    /// Shared instance
    static let shared = VersionService()

    /// Logger instance
    private let logger = FerrousLogger.app

    /// The current app version
    private(set) var currentVersion: String

    /// The latest available version
    private(set) var latestVersion: String?

    /// Whether an update is available
    private(set) var updateAvailable = false

    /// URL to the latest release
    private(set) var releaseURL: URL?

    /// GitHub token for authentication
    private var githubToken: String?

    /// URL session for network requests
    private let session: URLSession

    /// GitHub API URL for releases
    private let releasesURL: String

    /// Private initializer to enforce singleton pattern
    private init() {
        // Get the current app version
        currentVersion = Constants.version

        // Configure the releases URL
        // Default organization is "onefootball" and repo is "ferrous"
        // This should be updated from config if available
        var org = "motain"
        let repo = "ferrous"

        if let config = ConfigManager.shared.config?.tierZero?.github {
            org = config.organisation
        }

        releasesURL = "https://api.github.com/repos/\(org)/\(repo)/releases/latest"

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        session = URLSession(configuration: config)
        
        // Load GitHub token
        loadToken()

        FerrousLogger.shared.info("Initialized version service - current version: \(currentVersion)", log: logger)
    }

    /// Checks for available updates
    /// - Parameter completion: Callback with result containing update status or error
    func checkForUpdates(completion: @escaping (Result<Bool, Error>) -> Void) {
        FerrousLogger.shared.info("Checking for updates at \(releasesURL)", log: logger)

        guard let url = URL(string: releasesURL) else {
            FerrousLogger.shared.error("Invalid releases URL: \(releasesURL)", log: logger)
            completion(.failure(VersionError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        // Add auth token if available
        if let token = githubToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            FerrousLogger.shared.debug("Using GitHub token for version check", log: logger)
        } else {
            FerrousLogger.shared.warning("No GitHub token available for version check", log: logger)
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                FerrousLogger.shared.error("Network error checking for updates: \(error)", log: logger)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                FerrousLogger.shared.error("Invalid response type", log: logger)
                DispatchQueue.main.async {
                    completion(.failure(VersionError.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode != 200 {
                FerrousLogger.shared.error("HTTP error: \(httpResponse.statusCode)", log: logger)
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    FerrousLogger.shared.error("Authentication issue. Token may be invalid or missing.", log: logger)
                }
                DispatchQueue.main.async {
                    completion(.failure(VersionError.httpError(httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                FerrousLogger.shared.error("No data received", log: logger)
                DispatchQueue.main.async {
                    completion(.failure(VersionError.noData))
                }
                return
            }

            do {
                let releaseInfo = try JSONDecoder().decode(ReleaseInfo.self, from: data)

                // Extract version from tag (remove 'v' prefix if present)
                var version = releaseInfo.tag_name
                if version.hasPrefix("v") {
                    version = String(version.dropFirst())
                }

                self.latestVersion = version
                self.releaseURL = URL(string: releaseInfo.html_url)

                // Check if update is available
                let updateAvailable = self.isNewerVersion(version, than: self.currentVersion)
                self.updateAvailable = updateAvailable

                FerrousLogger.shared.debug("Update check complete - latest: \(version), updateAvailable: \(updateAvailable)", log: logger)

                DispatchQueue.main.async {
                    completion(.success(updateAvailable))
                }
            } catch {
                FerrousLogger.shared.error("Failed to parse release info: \(error)", log: logger)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        task.resume()
    }

    /// Compares two version strings to determine if one is newer
    /// - Parameters:
    ///   - version1: First version string
    ///   - version2: Second version string
    /// - Returns: `true` if version1 is newer than version2
    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        // Ensure both have the same number of components
        let maxComponents = max(v1Components.count, v2Components.count)
        let paddedV1 = v1Components + Array(repeating: 0, count: maxComponents - v1Components.count)
        let paddedV2 = v2Components + Array(repeating: 0, count: maxComponents - v2Components.count)

        // Compare each component
        for i in 0..<maxComponents {
            if paddedV1[i] > paddedV2[i] {
                return true
            } else if paddedV1[i] < paddedV2[i] {
                return false
            }
        }

        // Versions are identical
        return false
    }
    
    /// Loads the GitHub token from keychain, environment variable, or file
    private func loadToken() {
        // First try keychain
        if let keychainToken = loadTokenFromKeychain() {
            FerrousLogger.shared.debug("Using GitHub token from keychain", log: logger)
            githubToken = keychainToken
            return
        }
        
        // Next try environment variables using all common formats
        let envVarNames = ["GITHUB_TOKEN", "GH_TOKEN", "GITHUB_API_TOKEN", "GH_API_TOKEN"]
        
        for varName in envVarNames {
            if let envToken = ProcessInfo.processInfo.environment[varName], !envToken.isEmpty {
                FerrousLogger.shared.debug("Using GitHub token from environment variable \(varName)", log: logger)
                githubToken = envToken
                
                // Save to keychain for future use
                _ = saveTokenToKeychain(token: envToken)
                return
            }
        }
        
        // Try shell environment value via process
        if let shellToken = getTokenFromShellEnvironment() {
            FerrousLogger.shared.debug("Using GitHub token from shell environment", log: logger)
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
                        FerrousLogger.shared.debug("Loaded GitHub token from file: \(tokenPath.path)", log: logger)
                        
                        // Save to keychain for future use
                        _ = saveTokenToKeychain(token: token)
                        return
                    }
                } catch {
                    FerrousLogger.shared.error("Failed to load GitHub token from file \(tokenPath.path): \(error)", log: logger)
                }
            }
        }
        
        // If we've got this far, no token was found
        FerrousLogger.shared.warning("No GitHub token found in keychain, environment variables, or files", log: logger)
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
            FerrousLogger.shared.debug("Saved GitHub token to keychain", log: logger)
            return true
        } else {
            FerrousLogger.shared.error("Failed to save GitHub token to keychain. Status: \(status)", log: logger)
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

// MARK: - Version API Response Model

extension VersionService {
    /// GitHub release information
    struct ReleaseInfo: Decodable {
        let url: String
        let html_url: String
        let tag_name: String
        let name: String
        let published_at: String
    }
}

// MARK: - Version Errors

extension VersionService {
    /// Errors that can occur during version checking
    enum VersionError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case noData
        case parsingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL for version check"
            case .invalidResponse:
                return "Invalid response from version check"
            case .httpError(let code):
                return "HTTP error \(code) from version check"
            case .noData:
                return "No data received from version check"
            case .parsingError(let error):
                return "Failed to parse version information: \(error.localizedDescription)"
            }
        }
    }
}
