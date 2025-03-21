import Foundation

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

        logger.info("Initialized version service - current version: \(currentVersion)")
    }

    /// Checks for available updates
    /// - Parameter completion: Callback with result containing update status or error
    func checkForUpdates(completion: @escaping (Result<Bool, Error>) -> Void) {
        logger.info("Checking for updates at \(releasesURL)")

        guard let url = URL(string: releasesURL) else {
            logger.error("Invalid releases URL: \(releasesURL)")
            completion(.failure(VersionError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        // Add auth token if available
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Network error checking for updates: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Invalid response type")
                DispatchQueue.main.async {
                    completion(.failure(VersionError.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode != 200 {
                self.logger.error("HTTP error: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(VersionError.httpError(httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                self.logger.error("No data received")
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

                self.logger.debug("Update check complete - latest: \(version), updateAvailable: \(updateAvailable)")

                DispatchQueue.main.async {
                    completion(.success(updateAvailable))
                }
            } catch {
                self.logger.error("Failed to parse release info: \(error)")
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
