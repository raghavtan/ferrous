import Foundation

/// Represents the status of a command-line tool.
struct ToolStatus: Identifiable, Equatable {
    /// Unique identifier for the tool
    let id: String

    /// Display name of the tool
    let name: String

    /// Whether the tool is available and working
    let isAvailable: Bool

    /// Help text to describe the tool
    let helpText: String

    /// When the status was last checked
    let lastChecked: Date

    /// The check command that was executed to verify status
    let checkCommand: String

    /// Optional error message if tool is not available
    let errorMessage: String?

    init(id: String,
         name: String,
         isAvailable: Bool,
         helpText: String,
         lastChecked: Date = Date(),
         checkCommand: String,
         errorMessage: String? = nil) {
        self.id = id
        self.name = name
        self.isAvailable = isAvailable
        self.helpText = helpText
        self.lastChecked = lastChecked
        self.checkCommand = checkCommand
        self.errorMessage = errorMessage
    }

    // Conform to Identifiable with id
    var uid: String { id }

    // Conform to Equatable
    static func == (lhs: ToolStatus, rhs: ToolStatus) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isAvailable == rhs.isAvailable &&
               lhs.lastChecked == rhs.lastChecked
    }
}