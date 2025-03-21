import Foundation

/// Represents a GitHub pull request.
struct PullRequest: Identifiable, Equatable, Hashable {
    /// The pull request ID
    let id: Int

    /// The pull request title
    let title: String

    /// The repository name (format: "owner/repo")
    let repository: String

    /// The URL to the pull request
    let url: URL

    /// The author of the pull request
    let author: String

    /// When the pull request was created
    let createdAt: Date

    /// When the pull request was last updated
    let updatedAt: Date

    /// The current state of the pull request
    let state: State

    enum State: String, Equatable, Hashable {
        case open
        case closed
        case merged

        var isActive: Bool {
            return self == .open
        }
    }

    init(id: Int,
         title: String,
         repository: String,
         url: URL,
         author: String,
         createdAt: Date,
         updatedAt: Date,
         state: State) {
        self.id = id
        self.title = title
        self.repository = repository
        self.url = url
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
    }

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Conform to Equatable
    static func == (lhs: PullRequest, rhs: PullRequest) -> Bool {
        return lhs.id == rhs.id &&
               lhs.updatedAt == rhs.updatedAt &&
               lhs.state == rhs.state
    }

    /// Extract owner from repository (e.g., "octocat" from "octocat/hello-world")
    var repositoryOwner: String {
        let components = repository.split(separator: "/")
        return components.count > 0 ? String(components[0]) : ""
    }

    /// Extract repo name from repository (e.g., "hello-world" from "octocat/hello-world")
    var repositoryName: String {
        let components = repository.split(separator: "/")
        return components.count > 1 ? String(components[1]) : repository
    }

    /// Check if PR is authored by the specified user
    func isAuthoredBy(user: String) -> Bool {
        return author.lowercased() == user.lowercased()
    }

    /// Check if PR belongs to a repository matching a prefix
    func isInRepository(matching pattern: String) -> Bool {
        return repository.lowercased().contains(pattern.lowercased())
    }
}