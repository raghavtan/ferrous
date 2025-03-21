import SwiftUI

/// View that displays GitHub pull requests and related information
struct TierZeroView: View {
    /// The view model
    @StateObject private var viewModel = TierZeroViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User PR section
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Pull Requests")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 4)

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if viewModel.userPullRequests.isEmpty {
                    Text("No pull requests found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.userPullRequests.prefix(3)) { pr in
                        PullRequestRow(pullRequest: pr)
                    }

                    if viewModel.userPullRequests.count > 3 {
                        Text("+ \(viewModel.userPullRequests.count - 3) more...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Repository PR section
            VStack(alignment: .leading, spacing: 4) {
                Text("Repository Pull Requests")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 4)

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if viewModel.repoPullRequests.isEmpty {
                    Text("No pull requests found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(viewModel.repoPullRequests.prefix(3)) { pr in
                        PullRequestRow(pullRequest: pr)
                    }

                    if viewModel.repoPullRequests.count > 3 {
                        Text("+ \(viewModel.repoPullRequests.count - 3) more...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
        .onAppear {
            viewModel.loadPullRequests()
        }
    }
}

#Preview {
    TierZeroView()
        .padding()
        .frame(width: 300)
}