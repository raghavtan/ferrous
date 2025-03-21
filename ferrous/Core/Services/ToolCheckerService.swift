import Foundation

/// Service for checking the status of command-line tools.
final class ToolCheckService {
    /// Shared instance
    static let shared = ToolCheckService()

    /// Logger instance
    private let logger = FerrousLogger.tools

    /// The current status of all configured tools
    private(set) var toolStatuses: [String: ToolStatus] = [:]

    /// Tool configurations from the app config
    private var toolConfigs: [String: ToolConfig] = [:]

    /// Private initializer to enforce singleton pattern
    private init() {
        // Load tool configurations if available
        loadToolConfigurations()
    }

    /// Loads tool configurations from the app config
    func loadToolConfigurations() {
        guard let checkerConfig = ConfigManager.shared.config?.checker else {
            logger.warning("No tool checker configuration found")
            return
        }

        toolConfigs = checkerConfig.tools
        logger.debug("Loaded \(toolConfigs.count) tool configurations")
    }

    /// Checks the status of all configured tools
    /// - Parameter completion: Callback with result containing tool statuses or error
    func checkAllTools(completion: @escaping (Result<[ToolStatus], Error>) -> Void) {
        // Make sure we have tool configurations
        if toolConfigs.isEmpty {
            loadToolConfigurations()

            if toolConfigs.isEmpty {
                logger.warning("No tool configurations available")
                completion(.failure(ToolCheckError.noToolsConfigured))
                return
            }
        }

        logger.debug("Checking status of \(toolConfigs.count) tools")

        let dispatchGroup = DispatchGroup()
        var results: [String: ToolStatus] = [:]
        var errors: [Error] = []

        // Check each tool in parallel
        for (toolId, toolConfig) in toolConfigs {
            dispatchGroup.enter()

            checkTool(id: toolId, config: toolConfig) { result in
                switch result {
                case .success(let status):
                    results[toolId] = status
                case .failure(let error):
                    errors.append(error)
                    // Create a failed status anyway
                    results[toolId] = toolConfig.toDomainModel(
                        id: toolId,
                        isAvailable: false,
                        errorMessage: error.localizedDescription
                    )
                }

                dispatchGroup.leave()
            }
        }

        // When all checks complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Update stored statuses
            self.toolStatuses = results

            // Return all statuses, even if some failed
            let statuses = Array(results.values)
            self.logger.debug("Completed checking \(statuses.count) tools - \(statuses.filter { $0.isAvailable }.count) available")

            completion(.success(statuses))
        }
    }

    /// Checks the status of a specific tool
    /// - Parameters:
    ///   - id: The tool identifier
    ///   - config: The tool configuration
    ///   - completion: Callback with result containing tool status or error
    private func checkTool(id: String, config: ToolConfig, completion: @escaping (Result<ToolStatus, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            self.logger.debug("Checking tool: \(id) with command: \(config.checkCommand)")

            // Create a process to run the check command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", config.checkCommand]

            // Pipes for capturing output and errors
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                // Start the process
                try process.run()

                // Use a timeout mechanism
                let group = DispatchGroup()
                group.enter()

                // Background task to monitor process completion
                DispatchQueue.global(qos: .background).async {
                    process.waitUntilExit()
                    group.leave()
                }

                // Wait with timeout
                let result = group.wait(timeout: .now() + 5.0) // 5 second timeout

                // Handle timeout
                if result == .timedOut {
                    process.terminate()
                    self.logger.warning("Tool check timed out for \(id)")

                    let status = config.toDomainModel(
                        id: id,
                        isAvailable: false,
                        errorMessage: "Command timed out"
                    )

                    DispatchQueue.main.async {
                        completion(.success(status))
                    }
                    return
                }

                // Read output and error
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let _ = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                // Check if successful
                let isAvailable = process.terminationStatus == 0
                let errorMessage = isAvailable ? nil : (error.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : error.trimmingCharacters(in: .whitespacesAndNewlines))

                let status = config.toDomainModel(
                    id: id,
                    isAvailable: isAvailable,
                    errorMessage: errorMessage
                )

                self.logger.debug("Tool \(id) check result: \(isAvailable ? "available" : "unavailable")")

                DispatchQueue.main.async {
                    completion(.success(status))
                }
            } catch {
                self.logger.error("Failed to check tool \(id): \(error)")

                let status = config.toDomainModel(
                    id: id,
                    isAvailable: false,
                    errorMessage: "Failed to execute check: \(error.localizedDescription)"
                )

                DispatchQueue.main.async {
                    completion(.success(status))
                }
            }
        }
    }
}

// MARK: - Tool Check Errors

extension ToolCheckService {
    /// Errors that can occur during tool checking
    enum ToolCheckError: Error, LocalizedError {
        case noToolsConfigured
        case commandFailed(String, Int32)
        case executionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noToolsConfigured:
                return "No tools configured for checking"
            case .commandFailed(let command, let exitCode):
                return "Command failed: \(command) (exit code: \(exitCode))"
            case .executionFailed(let error):
                return "Failed to execute command: \(error.localizedDescription)"
            }
        }
    }
}
