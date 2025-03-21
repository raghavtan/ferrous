import Foundation

/// Represents a custom action in the app, either a URL link or a dynamic dropdown.
struct CustomAction: Identifiable, Equatable {
    /// The display title for the action
    let title: String

    /// Help text describing the action
    let help: String

    /// The type of the action
    let type: ActionType

    /// For URL type: The URL to open
    let url: URL?

    /// For dynamic dropdown type: Path to the file containing options
    let filePath: String?

    /// For dynamic dropdown type: Path expression to extract options from the file
    let pathExpression: String?

    /// For dynamic dropdown type: Parser to use for the file
    let parser: ParserType?

    enum ActionType: String, Equatable {
        case url
        case dynamicDropdown
    }

    enum ParserType: String, Equatable {
        case yaml
        case toml
        case json
    }

    init(title: String,
         help: String,
         type: ActionType,
         url: URL? = nil,
         filePath: String? = nil,
         pathExpression: String? = nil,
         parser: ParserType? = nil) {
        self.title = title
        self.help = help
        self.type = type
        self.url = url
        self.filePath = filePath
        self.pathExpression = pathExpression
        self.parser = parser
    }

    // Conform to Identifiable
    var id: String { title }

    // Conform to Equatable
    static func == (lhs: CustomAction, rhs: CustomAction) -> Bool {
        return lhs.title == rhs.title &&
               lhs.type == rhs.type
    }

    /// Create a URL action
    static func urlAction(title: String, help: String, url: URL) -> CustomAction {
        return CustomAction(
            title: title,
            help: help,
            type: .url,
            url: url
        )
    }

    /// Create a dynamic dropdown action
    static func dropdownAction(
        title: String,
        help: String,
        filePath: String,
        pathExpression: String,
        parser: ParserType
    ) -> CustomAction {
        return CustomAction(
            title: title,
            help: help,
            type: .dynamicDropdown,
            filePath: filePath,
            pathExpression: pathExpression,
            parser: parser
        )
    }
}

/// Represents a simple link for display in the app.
struct CustomLink: Identifiable, Equatable {
    /// The display name for the link
    let name: String

    /// The URL to open
    let url: String

    // Conform to Identifiable
    var id: String { name }

    // Conform to Equatable
    static func == (lhs: CustomLink, rhs: CustomLink) -> Bool {
        return lhs.name == rhs.name && lhs.url == rhs.url
    }

    /// Get a URL object from the string URL
    var urlObject: URL? {
        return URL(string: url)
    }
}