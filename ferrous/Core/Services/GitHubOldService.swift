///// A model representing an issue item, used for search results.
///// Conforms to `Codable` for JSON decoding.
//struct IssueItem: Codable {
//    let id: Int
//    let number: Int
//    let title: String
//    let html_url: String
//}
//
///// A model representing the result of a GitHub search query.
///// Conforms to `Codable` for JSON decoding.
//struct SearchResult: Codable {
//    let items: [IssueItem]
//}
//
///// A model representing a GitHub release.
///// This is used to decode the response from the GitHub API for the latest release.
//struct GitHubRelease: Codable {
//    let tag_name: String
//}
//
//// MARK: - GitHub Service
//
///// A service responsible for interacting with the GitHub API.
/////
///// Provides methods to:
///// - Add an authorization header.
///// - Extract repository names from URLs.
///// - Perform generic API requests.
///// - Fetch pull requests for users, teams, or repositories.
///// - Fetch teams for the authenticated user.
///// - **Fetch the latest release version for update checks.**
/////
///// This class is implemented as a singleton.
//final class GitHubService {
//
//    /// Shared singleton instance of `GitHubService`.
//    static let shared = GitHubService()
//
//    /// Private initializer to enforce singleton usage.
//    private init() {}
//
//    // MARK: - Private Helper Methods
//
//    /**
//     Adds the GitHub authorization header to the provided URL request if a valid token exists.
//
//     The token is retrieved from the environment variable `GITHUB_TOKEN`. If present and not empty, the header
//     is added in the format "token {token}". For logging purposes, only the last 4 characters of the token are shown.
//
//     - Parameter request: The URLRequest to which the authorization header will be added.
//     */
//    private func addAuthHeader(to request: inout URLRequest) {
//        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"],
//           !token.isEmpty
//        {
//            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
//            let maskedToken = String(repeating: "*", count: max(0, token.count - 4)) + token.suffix(4)
//            os_log("Using GITHUB_TOKEN: %{public}@", log: gitHubLogger, type: .info, maskedToken)
//        } else {
//            os_log("GITHUB_TOKEN not found or is empty.", log: gitHubLogger, type: .error)
//        }
//    }
//
//    /**
//     Extracts the repository name from a GitHub pull request HTML URL.
//
//     The method parses the URL and retrieves the second and third components to form a repository name in the format "owner/repo".
//
//     - Parameter htmlURL: The HTML URL string from which to extract the repository name.
//     - Returns: A repository name string if extraction is successful; otherwise, `nil`.
//     */
//    private func extractRepoName(from htmlURL: String) -> String? {
//        guard let url = URL(string: htmlURL) else { return nil }
//        let components = url.pathComponents
//        guard components.count >= 3 else { return nil }
//        return "\(components[1])/\(components[2])"
//    }
//
//    /**
//     Performs a GitHub API request and decodes the response.
//
//     This generic method logs the request, performs the network call, logs the HTTP status code, and attempts to decode
//     the response into the specified type.
//
//     - Parameter request: The URLRequest to be executed.
//     - Returns: An instance of type `T` decoded from the API response.
//     - Throws: `GitHubServiceError.apiError` if the API returns an error message,
//               `GitHubServiceError.decodingError` if decoding fails,
//               or any other error encountered during the network request.
//     */
//    private func performRequest<T: Decodable>(with request: URLRequest) async throws -> T {
//        os_log("Performing GitHub API request to: %{public}@", log: gitHubLogger, type: .info, request.url?.absoluteString ?? "Unknown URL")
//        let (data, response) = try await URLSession.shared.data(for: request)
//
//        if let httpResponse = response as? HTTPURLResponse {
//            os_log("HTTP status code: %{public}d", log: gitHubLogger, type: .info, httpResponse.statusCode)
//        }
//
//        do {
//            let decoded = try JSONDecoder().decode(T.self, from: data)
//            return decoded
//        } catch {
//            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
//               let message = errorResponse["message"] {
//                os_log("GitHub API error: %{public}@", log: gitHubLogger, type: .error, message)
//                throw GitHubServiceError.apiError(message: message)
//            }
//
//            let requestDetails = """
//            URL: \(request.url?.absoluteString ?? "Unknown URL")
//            HTTP Method: \(request.httpMethod ?? "Unknown")
//            Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "No Body")
//            """
//
//            var responseDetails = "Response: "
//            if let httpResponse = response as? HTTPURLResponse {
//                responseDetails += "URL: \(httpResponse.url?.absoluteString ?? "Unknown URL"), " +
//                                   "Status Code: \(httpResponse.statusCode)"
//            } else {
//                responseDetails += "\(response)"
//            }
//
//            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response body to string"
//
//            os_log("Decoding error: %{public}@\nRequest: %{public}@\n%{public}@\nResponse Body: %{public}@",
//                   log: gitHubLogger, type: .error,
//                   "\(error)",
//                   requestDetails,
//                   responseDetails,
//                   responseBody)
//            throw GitHubServiceError.decodingError(error)
//        }
//    }
//
//    // MARK: - Public API Methods
//
//    /**
//     Fetches open pull requests authored by the specified user.
//
//     Constructs a search query to find open pull requests where the specified user is the author.
//
//     - Parameter username: The GitHub username for which to fetch pull requests.
//     - Returns: An array of `PullRequest` objects representing the open pull requests authored by the user.
//     - Throws: `GitHubServiceError.invalidURL` if the URL is invalid,
//               or errors thrown by `performRequest(_:)`.
//     */
//    func fetchUserPRs(for username: String) async throws -> [PullRequest] {
//        let requestedQuery = "is:pr+is:open+review-requested:\(username)"
//        let authoredQuery = "is:pr+is:open+author:\(username)"
//        var mergedResults: [PullRequest] = []
//
//        for query in [requestedQuery, authoredQuery] {
//            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
//                  let url = URL(string: "https://api.github.com/search/issues?q=\(encodedQuery)")
//            else {
//                throw GitHubServiceError.invalidURL
//            }
//
//            var request = URLRequest(url: url)
//            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
//            addAuthHeader(to: &request)
//
//            let result: SearchResult = try await performRequest(with: request)
//            let pullRequests = result.items.compactMap { item -> PullRequest? in
//                guard let repoName = self.extractRepoName(from: item.html_url) else { return nil }
//                return PullRequest(
//                    id: item.id,
//                    number: item.number,
//                    title: item.title,
//                    repositoryName: repoName,
//                    htmlURL: item.html_url
//                )
//            }
//
//            mergedResults.append(contentsOf: pullRequests)
//        }
//
//        return mergedResults
//    }
//
//    /**
//     Fetches open pull requests for a given repository.
//
//     Constructs the URL for the repository's pull requests endpoint and returns the corresponding pull requests.
//
//     - Parameter repository: A string representing the repository in the format "owner/repo".
//     - Returns: An array of `PullRequest` objects representing the open pull requests for the repository.
//     - Throws: `GitHubServiceError.invalidURL` if the URL is invalid,
//               or errors thrown by `performRequest(_:)`.
//     */
//    func fetchRepositoryPRs(for repository: String) async throws -> [PullRequest] {
//        let trimmedRepo = repository.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard let url = URL(string: "https://api.github.com/repos/\(trimmedRepo)/pulls") else {
//            throw GitHubServiceError.invalidURL
//        }
//        os_log("Fetching PRs for repository: %{public}@ using URL: %{public}@",
//               log: gitHubLogger, type: .info, trimmedRepo, url.absoluteString)
//
//        var request = URLRequest(url: url)
//        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
//        addAuthHeader(to: &request)
//
//        let prItems: [RepositoryPRItem] = try await performRequest(with: request)
//        return prItems.map { item in
//            PullRequest(
//                id: item.id,
//                number: item.number,
//                title: item.title,
//                repositoryName: trimmedRepo,
//                htmlURL: item.html_url
//            )
//        }
//    }
//
//    // MARK: - Latest Release Check
//
//    /**
//     Fetches the latest release version from the GitHub releases endpoint for ferrous.
//
//     This method calls the GitHub API endpoint for the latest release
//     at "https://api.github.com/repos/motain/ferrous/releases/latest" and returns the `tag_name`.
//
//     - Returns: A `String` representing the latest release version.
//     - Throws: `GitHubServiceError.invalidURL` if the URL is invalid,
//               or errors thrown by `performRequest(_:)`.
//     */
//    func fetchLatestReleaseVersion() async throws -> String {
//        guard let url = URL(string: "https://api.github.com/repos/motain/ferrous/releases/latest") else {
//            throw GitHubServiceError.invalidURL
//        }
//        var request = URLRequest(url: url)
//        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
//        addAuthHeader(to: &request)
//
//        let release: GitHubRelease = try await performRequest(with: request)
//        return release.tag_name
//    }
//}
