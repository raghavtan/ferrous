import SwiftUI

/// A row displaying a GitHub pull request
struct PullRequestRow: View {
    /// The pull request to display
    let pullRequest: PullRequest

    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(pullRequest.url)
        }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pullRequest.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    Text(pullRequest.repository)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Text(pullRequest.author)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(pullRequest.updatedAt.timeAgo())
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open in Browser") {
                NSWorkspace.shared.open(pullRequest.url)
            }

            Button("Copy URL") {
                copyToClipboard(pullRequest.url.absoluteString)
            }

            Button("Copy Title") {
                copyToClipboard(pullRequest.title)
            }

            Divider()

            Text("Created: \(formattedDate(pullRequest.createdAt))")
            Text("Updated: \(formattedDate(pullRequest.updatedAt))")
            Text("State: \(pullRequest.state.rawValue.capitalizingFirstLetter)")
        }
    }

    /// Copies text to the clipboard
    /// - Parameter text: The text to copy
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Formats a date for display
    /// - Parameter date: The date to format
    /// - Returns: A formatted date string
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack {
        PullRequestRow(
            pullRequest: PullRequest(
                id: 101,
                title: "Add new feature",
                repository: "onefootball/ferrous",
                url: URL(string: "https://github.com/onefootball/ferrous/pull/101")!,
                author: "user1",
                createdAt: Date().addingTimeInterval(-86400), // 1 day ago
                updatedAt: Date().addingTimeInterval(-3600),  // 1 hour ago
                state: .open
            )
        )

        PullRequestRow(
            pullRequest: PullRequest(
                id: 102,
                title: "Fix bug in tool checker with very long title that should be truncated",
                repository: "onefootball/another-repo",
                url: URL(string: "https://github.com/onefootball/another-repo/pull/102")!,
                author: "user2",
                createdAt: Date().addingTimeInterval(-43200), // 12 hours ago
                updatedAt: Date().addingTimeInterval(-1800),  // 30 mins ago
                state: .open
            )
        )
    }
    .padding()
    .frame(width: 300)
}