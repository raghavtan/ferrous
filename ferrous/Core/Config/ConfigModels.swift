import Foundation

/// The main configuration structure for the app.
/// The main configuration structure for the app.
struct AppConfig: Codable {
    /// Tier Zero configuration (GitHub and links)
    var tierZero: TierZeroConfig?
    
    /// Tools checker configuration
    var checker: CheckerConfig?
    
    /// Additional custom actions
    var actions: [String: CustomActionConfig]?
    
    enum CodingKeys: String, CodingKey {
        case tierZero = "tierzero"
        case checker
        case actions
    }
}

/// Tier Zero configuration for GitHub and important links.
struct TierZeroConfig: Codable {
    /// GitHub configuration
    var github: GitHubConfig

    /// Important links
    var links: [CustomLinkConfig]?
}

/// GitHub configuration.
struct GitHubConfig: Codable {
    /// The GitHub username
    var user: String

    /// The GitHub organization
    var organisation: String

    /// The timezone for displaying times
    var timezone: String

    /// Repositories to monitor
    var repositories: [String]
}

/// Custom link configuration.
struct CustomLinkConfig: Codable {
    /// The display name for the link
    var name: String

    /// The URL to open
    var url: String

    /// Convert to a CustomLink domain model
    func toDomainModel() -> CustomLink {
        return CustomLink(name: name, url: url)
    }
}

/// Tool checker configuration.
struct CheckerConfig: Codable {
    /// Configuration for individual tools
    var tools: [String: ToolConfig]
}

/// Configuration for a specific tool to check.
struct ToolConfig: Codable {
    /// The display title for the tool
    var title: String
    
    /// Help text describing the tool
    var help: String
    
    /// The command to execute to check the tool's status
    var checkCommand: String
    
    /// Convert to a ToolStatus domain model
    func toDomainModel(id: String, isAvailable: Bool, lastChecked: Date = Date(), errorMessage: String? = nil) -> ToolStatus {
        return ToolStatus(
            id: id,
            name: title,
            isAvailable: isAvailable,
            helpText: help,
            lastChecked: lastChecked,
            checkCommand: checkCommand,
            errorMessage: errorMessage
        )
    }
}

/// Custom action configuration.
struct CustomActionConfig: Codable {
    /// The display title for the action
    var title: String
    
    /// Help text describing the action
    var help: String
    
    /// The type of the action (url, dynamicDropdown)
    var type: String
    
    /// For URL type: The URL to open
    var url: String?
    
    /// For dynamic dropdown type: Path to the file containing options
    var file: String?
    
    /// For dynamic dropdown type: Path expression to extract options from the file
    var jsonPathExpressions: String?
    
    /// For dynamic dropdown type: Parser to use for the file
    var parser: String?
    
    /// Convert to a CustomAction domain model
    func toDomainModel(key: String) -> CustomAction? {
        // Parse the action type
        guard let actionType = CustomAction.ActionType(rawValue: type.lowercased()) else {
            return nil
        }
        
        // For URL type
        if actionType == .url, let urlString = url, let url = URL(string: urlString) {
            return CustomAction.urlAction(title: title, help: help, url: url)
        }
        
        // For dynamic dropdown type
        if actionType == .dynamicDropdown,
           let filePath = file,
           let pathExpr = jsonPathExpressions,
           let parserStr = parser,
           let parserType = CustomAction.ParserType(rawValue: parserStr.lowercased()) {
            return CustomAction.dropdownAction(
                title: title,
                help: help,
                filePath: filePath,
                pathExpression: pathExpr,
                parser: parserType
            )
        }
        
        return nil
    }
}
