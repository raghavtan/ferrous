import Foundation
import Yams

/// Service for interacting with Kubernetes, including checking contexts and updating kubeconfig.
final class KubernetesService {
    /// Shared instance
    static let shared = KubernetesService()

    /// Logger instance
    private let logger = FerrousLogger.kubernetes

    /// The local Kubernetes context
    private(set) var localContext: KubernetesContext?

    /// The remote stable Kubernetes context from AWS
    private(set) var stableContext: KubernetesContext?

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Refreshes both local and remote Kubernetes contexts
    /// - Parameter completion: Callback with result containing success status or error
    func refreshContexts(completion: @escaping (Result<Void, Error>) -> Void) {
        let dispatchGroup = DispatchGroup()

        var localError: Error?
        var remoteError: Error?

        // Refresh local context
        dispatchGroup.enter()
        refreshLocalContext { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                localError = error
            }
            dispatchGroup.leave()
        }

        // Refresh remote context
        dispatchGroup.enter()
        refreshStableContext { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                remoteError = error
            }
            dispatchGroup.leave()
        }

        // Wait for both operations to complete
        dispatchGroup.notify(queue: .main) {
            // If both failed, return the local error (or remote if no local error)
            if let localError = localError, let remoteError = remoteError {
                self.logger.error("Both context refreshes failed - local: \(localError), remote: \(remoteError)")
                completion(.failure(localError))
                return
            }

            // If either succeeded, consider it a success
            if localError == nil || remoteError == nil {
                self.logger.debug("Contexts refreshed - local: \(self.localContext != nil), remote: \(self.stableContext != nil)")
                completion(.success(()))
            } else if let localError = localError {
                completion(.failure(localError))
            } else if let remoteError = remoteError {
                completion(.failure(remoteError))
            }
        }
    }

    /// Refreshes the local Kubernetes context
    /// - Parameter completion: Callback with result containing success status or error
    func refreshLocalContext(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // Read the kubeconfig file
                let kubeConfigPath = Constants.Path.kubeConfig

                // Check if file exists
                guard FileManager.default.fileExists(atPath: kubeConfigPath.path) else {
                    self.logger.warning("Kubeconfig file not found at \(kubeConfigPath.path)")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.configNotFound))
                    }
                    return
                }

                // Read and parse the YAML
                let kubeConfigYaml = try String(contentsOf: kubeConfigPath, encoding: .utf8)
                guard let kubeConfig = try Yams.load(yaml: kubeConfigYaml) as? [String: Any] else {
                    self.logger.error("Failed to parse kubeconfig as YAML")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.invalidConfig))
                    }
                    return
                }

                // Extract current context name
                guard let currentContextName = kubeConfig["current-context"] as? String else {
                    self.logger.warning("No current-context found in kubeconfig")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.noCurrentContext))
                    }
                    return
                }

                // Find the context in the contexts list
                guard let contexts = kubeConfig["contexts"] as? [[String: Any]] else {
                    self.logger.warning("No contexts found in kubeconfig")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.noContexts))
                    }
                    return
                }

                var foundContextDetails: [String: Any]?

                for context in contexts {
                    if let name = context["name"] as? String, name == currentContextName {
                        foundContextDetails = context["context"] as? [String: Any]
                        break
                    }
                }

                guard let contextDetails = foundContextDetails else {
                    self.logger.warning("Current context details not found")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.contextDetailsNotFound))
                    }
                    return
                }

                // Extract cluster name
                guard let clusterName = contextDetails["cluster"] as? String else {
                    self.logger.warning("Cluster name not found in current context")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.clusterNotFound))
                    }
                    return
                }

                // Extract namespace if available
                let namespace = contextDetails["namespace"] as? String

                // Find if this is a stable context
                let isStable = self.stableContext != nil && self.stripArnPrefix(from: clusterName) == self.stableContext?.name

                // Create and store the context
                let context = KubernetesContext(
                    name: currentContextName,
                    cluster: self.stripArnPrefix(from: clusterName),
                    isActive: true,
                    isStable: isStable,
                    namespace: namespace
                )

                self.localContext = context
                self.logger.debug("Local context updated: \(context.name) (\(context.cluster))")

                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                self.logger.error("Error refreshing local context: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Refreshes the stable Kubernetes context from AWS EKS
    /// - Parameter completion: Callback with result containing success status or error
    func refreshStableContext(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // In a real implementation, this would use the AWS SDK or aws-cli
            // For simplicity, we're using the shell command approach

            // List EKS clusters
            let (output, error, exitCode) = Process.shell("aws eks list-clusters --region eu-west-1")

            if exitCode != 0 {
                self.logger.error("Failed to list EKS clusters: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(KubernetesError.eksCommandFailed(error)))
                }
                return
            }

            // Parse the JSON output
            do {
                guard let jsonData = output.data(using: .utf8) else {
                    self.logger.error("Could not convert output to data")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.invalidOutput))
                    }
                    return
                }

                let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                guard let clusters = json?["clusters"] as? [String] else {
                    self.logger.error("Could not parse clusters from JSON")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.invalidOutput))
                    }
                    return
                }

                if clusters.isEmpty {
                    self.logger.warning("No EKS clusters found")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.noClusters))
                    }
                    return
                }

                // Find the first cluster with a stable-related name
                // In a real implementation, check for a "Stable" tag
                var stableClusterName: String?

                for cluster in clusters {
                    if cluster.lowercased().contains("stable") {
                        stableClusterName = cluster
                        break
                    }
                }

                // If no stable cluster found, use the first cluster
                if stableClusterName == nil && !clusters.isEmpty {
                    stableClusterName = clusters[0]
                }

                guard let clusterName = stableClusterName else {
                    self.logger.warning("Could not determine stable cluster")
                    DispatchQueue.main.async {
                        completion(.failure(KubernetesError.noStableCluster))
                    }
                    return
                }

                // Create and store the context
                let context = KubernetesContext(
                    name: clusterName,
                    cluster: clusterName,
                    isActive: false,
                    isStable: true
                )

                self.stableContext = context
                self.logger.debug("Stable context updated: \(context.name)")

                // Update local context's isStable flag if needed
                if let localContext = self.localContext {
                    let isStable = self.stripArnPrefix(from: localContext.cluster) == clusterName
                    if localContext.isStable != isStable {
                        self.localContext = localContext.with(isStable: isStable)
                    }
                }

                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                self.logger.error("Error parsing EKS output: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Updates the kubeconfig file to use the stable context
    /// - Parameter completion: Callback with result containing success status or error
    func updateKubeConfig(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let stableContext = stableContext else {
            logger.warning("No stable context available")
            completion(.failure(KubernetesError.noStableCluster))
            return
        }

        logger.info("Updating kubeconfig to use stable context: \(stableContext.name)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Execute the aws eks update-kubeconfig command
            let command = "aws eks update-kubeconfig --name \(stableContext.name) --region eu-west-1"
            let (_, error, exitCode) = Process.shell(command)

            if exitCode != 0 {
                self.logger.error("Failed to update kubeconfig: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(KubernetesError.updateFailed(error)))
                }
                return
            }

            // Wait a moment for file system updates
            Thread.sleep(forTimeInterval: 1.0)

            // Refresh local context to reflect changes
            self.refreshLocalContext { result in
                switch result {
                case .success:
                    self.logger.info("Kubeconfig updated successfully")
                    completion(.success(()))
                case .failure(let error):
                    self.logger.error("Failed to refresh local context after update: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }

    /// Strips the AWS ARN prefix from a cluster name
    /// - Parameter clusterName: The cluster name, possibly with ARN prefix
    /// - Returns: The cluster name without ARN prefix
    private func stripArnPrefix(from clusterName: String) -> String {
        let arnPrefix = "arn:aws:eks:eu-west-1:"

        if clusterName.contains(arnPrefix) {
            // Extract the cluster name from the ARN
            let components = clusterName.components(separatedBy: ":")
            if components.count > 4 {
                let lastPart = components.last ?? ""
                let clusterComponents = lastPart.components(separatedBy: "/")
                if clusterComponents.count > 1 {
                    return clusterComponents.last ?? clusterName
                }
            }
        }

        return clusterName
    }
}

// MARK: - Kubernetes Errors

extension KubernetesService {
    /// Errors that can occur during Kubernetes operations
    enum KubernetesError: Error, LocalizedError {
        case configNotFound
        case invalidConfig
        case noCurrentContext
        case noContexts
        case contextDetailsNotFound
        case clusterNotFound
        case noClusters
        case noStableCluster
        case eksCommandFailed(String)
        case invalidOutput
        case updateFailed(String)

        var errorDescription: String? {
            switch self {
            case .configNotFound:
                return "Kubernetes config file not found"
            case .invalidConfig:
                return "Invalid Kubernetes config file"
            case .noCurrentContext:
                return "No current context defined in Kubernetes config"
            case .noContexts:
                return "No contexts found in Kubernetes config"
            case .contextDetailsNotFound:
                return "Context details not found for current context"
            case .clusterNotFound:
                return "Cluster name not found in current context"
            case .noClusters:
                return "No EKS clusters found"
            case .noStableCluster:
                return "No stable EKS cluster found"
            case .eksCommandFailed(let error):
                return "EKS command failed: \(error)"
            case .invalidOutput:
                return "Invalid output from EKS command"
            case .updateFailed(let error):
                return "Failed to update kubeconfig: \(error)"
            }
        }
    }
}
