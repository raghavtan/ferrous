import SwiftUI

/// View that displays Kubernetes context information and update controls
struct KubernetesView: View {
    /// The view model
    @StateObject private var viewModel = KubernetesViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Local context section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Local")
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                }

                if let localContext = viewModel.localContext {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localContext.name)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)

                            Text(localContext.cluster)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if localContext.isStable {
                            Text("✅")
                                .font(.system(size: 11))
                        } else {
                            Text("⚠️")
                                .font(.system(size: 11))
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.1)))
                } else {
                    Text("No local context found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
            }

            // Remote/Stable context section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Remote")
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                }

                if let stableContext = viewModel.stableContext {
                    HStack {
                        Text(stableContext.name)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)

                        Spacer()

                        Text("Stable")
                            .font(.system(size: 9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.1)))
                } else {
                    Text("No stable cluster found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
            }

            // Update button if contexts differ
            if viewModel.shouldShowUpdateButton {
                Button(action: {
                    viewModel.updateKubeConfig()
                }) {
                    if viewModel.isUpdating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.6)

                            Text("Updating...")
                                .font(.system(size: 11))
                        }
                    } else {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))

                            Text("Update to Stable")
                                .font(.system(size: 11))
                        }
                    }
                }
                .disabled(viewModel.isUpdating || viewModel.stableContext == nil)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }

            // Error message (if any)
            if let error = viewModel.error {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
    }
}

#Preview {
    KubernetesView()
        .padding()
        .frame(width: 300)
}