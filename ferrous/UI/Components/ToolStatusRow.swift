import SwiftUI

/// A row displaying the status of a tool
struct ToolStatusRow: View {
    /// The tool status to display
    let status: ToolStatus

    /// Whether to show the last checked time
    var showLastChecked: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(status.isAvailable ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Tool name
            Text(status.name)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            // Last checked time (if enabled)
            if showLastChecked, let timeAgo = status.lastChecked.timeAgo() as String? {
                Text(timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Status symbol
            Text(status.isAvailable ? "✅" : "❌")
                .font(.system(size: 12))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .help(status.isAvailable ? status.helpText : (status.errorMessage ?? status.helpText))
        .contextMenu {
            if let errorMessage = status.errorMessage {
                Text("Error: \(errorMessage)")
            }

            Text("Command: \(status.checkCommand)")

            Button("Copy Error") {
                copyToClipboard(status.errorMessage ?? "No error")
            }
            .disabled(status.errorMessage == nil)

            Button("Copy Command") {
                copyToClipboard(status.checkCommand)
            }
        }
    }

    /// Copies text to the clipboard
    /// - Parameter text: The text to copy
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    VStack {
        ToolStatusRow(
            status: ToolStatus(
                id: "kubectl",
                name: "kubectl",
                isAvailable: true,
                helpText: "Kubernetes command-line tool",
                checkCommand: "which kubectl"
            )
        )

        ToolStatusRow(
            status: ToolStatus(
                id: "helm",
                name: "helm",
                isAvailable: false,
                helpText: "Kubernetes package manager",
                checkCommand: "which helm",
                errorMessage: "Command not found"
            ),
            showLastChecked: true
        )
    }
    .padding()
}