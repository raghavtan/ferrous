import Foundation
import Combine

/// View model for the Kubernetes view
final class KubernetesViewModel: ObservableObject {
    /// The local Kubernetes context
    @Published var localContext: KubernetesContext?

    /// The remote/stable Kubernetes context
    @Published var stableContext: KubernetesContext?

    /// Whether an update is in progress
    @Published var isUpdating = false

    /// Error message, if any
    @Published var error: String?

    /// Whether to show the update button
    var shouldShowUpdateButton: Bool {
        // Show if we have both contexts and the local one is not stable
        guard let localContext = localContext, stableContext != nil else {
            return false
        }
        return !localContext.isStable
    }

    /// Logger instance
    private let logger = FerrousLogger.kubernetes

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Initializes the view model
    init() {
        // Subscribe to Kubernetes context updates from BackgroundService
        BackgroundService.shared.kubernetesContextsUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contexts in
                self?.localContext = contexts.local
                self?.stableContext = contexts.remote
            }
            .store(in: &cancellables)

        // Get initial values if available
        MainMenuViewModel.shared.$localKubernetesContext
            .receive(on: DispatchQueue.main)
            .assign(to: &$localContext)

        MainMenuViewModel.shared.$remoteKubernetesContext
            .receive(on: DispatchQueue.main)
            .assign(to: &$stableContext)
    }

    /// Updates the kubeconfig to use the stable context
    func updateKubeConfig() {
        guard let stableContext = stableContext else {
            error = "No stable context available"
            return
        }

        isUpdating = true
        error = nil

        FerrousLogger.shared.info("Updating kubeconfig to use stable context: \(stableContext.name)", log: logger)

        KubernetesService.shared.updateKubeConfig { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.isUpdating = false

                switch result {
                case .success:
                    FerrousLogger.shared.info("Kubeconfig updated successfully", log: self.logger)
                    // Refresh the contexts to show the update
                    BackgroundService.shared.refreshKubernetesContexts()

                case .failure(let updateError):
                    self.error = updateError.localizedDescription
                    FerrousLogger.shared.error("Failed to update kubeconfig: \(updateError)", log: self.logger)
                }
            }
        }
    }
}
