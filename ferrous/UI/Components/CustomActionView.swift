import SwiftUI
import Yams

/// View for displaying and interacting with a custom action
struct CustomActionView: View {
    /// The action to display
    let action: CustomAction

    /// Options for dynamic dropdown actions
    @State private var options: [String] = []

    /// Whether options are being loaded
    @State private var isLoadingOptions = false

    /// Logger instance
    private let logger = FerrousLogger.app

    var body: some View {
        Group {
            switch action.type {
            case .url:
                urlActionView

            case .dynamicDropdown:
                dynamicDropdownView
            }
        }
        .onAppear {
            if action.type == .dynamicDropdown {
                loadOptions()
            }
        }
    }

    /// View for URL type actions
    private var urlActionView: some View {
        Button(action: {
            if let url = action.url {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Text(action.title)
                    .font(.system(size: 11))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .disabled(action.url == nil)
        .help(action.help)
    }

    /// View for dynamic dropdown type actions
    private var dynamicDropdownView: some View {
        Menu {
            if isLoadingOptions {
                Text("Loading options...")
                    .font(.system(size: 11))
            } else if options.isEmpty {
                Text("No options available")
                    .font(.system(size: 11))
            } else {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        executeAction(for: option)
                    }) {
                        Text(option)
                            .font(.system(size: 11))
                    }
                }
            }
        } label: {
            HStack {
                Text(action.title)
                    .font(.system(size: 11))

                Spacer()

                if isLoadingOptions {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.5)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
            }
            .padding(.vertical, 3)
        }
        .menuStyle(.automatic)
        .help(action.help)
    }

    /// Loads options for dynamic dropdown actions
    private func loadOptions() {
        guard case .dynamicDropdown = action.type else { return }

        isLoadingOptions = true

        DispatchQueue.global(qos: .userInitiated).async {
            var loadedOptions: [String] = []

            // Check if we have all required properties
            if let filePath = action.filePath,
               let pathExpression = action.pathExpression,
               let parser = action.parser {

                do {
                    // Expand tilde in path if needed
                    var expandedPath = filePath
                    if filePath.hasPrefix("~") {
                        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                        expandedPath = homeDir + filePath.dropFirst()
                    }

                    // Check if file exists
                    guard FileManager.default.fileExists(atPath: expandedPath) else {
                        throw CustomActionError.fileNotFound(expandedPath)
                    }

                    // Parse based on file type
                    switch parser {
                    case .yaml:
                        // Read and parse YAML
                        let yamlData = try String(contentsOfFile: expandedPath, encoding: .utf8)
                        guard let yaml = try Yams.load(yaml: yamlData) as? [String: Any] else {
                            throw CustomActionError.parsingFailed("Failed to parse YAML")
                        }

                        // Extract values using JSONPath-like expression
                        if pathExpression == "$..name" {
                            // Simple implementation for the common case
                            extractNames(from: yaml, into: &loadedOptions)
                        }

                    case .toml:
                        // For TOML, we use a simple parser (could use a proper TOML library)
                        // This is just a simple example to handle something like ~/.saml2aws
                        let tomlData = try String(contentsOfFile: expandedPath, encoding: .utf8)
                        let lines = tomlData.split(separator: "\n")

                        // Extract section headers (they look like [name])
                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                                let name = String(trimmed.dropFirst().dropLast())
                                if !name.isEmpty {
                                    loadedOptions.append(name)
                                }
                            }
                        }

                    case .json:
                        // Read and parse JSON
                        let jsonData = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
                        let json = try JSONSerialization.jsonObject(with: jsonData)

                        // Extract values using JSONPath-like expression
                        if pathExpression == "$..name" {
                            if let dict = json as? [String: Any] {
                                extractNames(from: dict, into: &loadedOptions)
                            } else if let array = json as? [Any] {
                                for item in array {
                                    if let dict = item as? [String: Any] {
                                        extractNames(from: dict, into: &loadedOptions)
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    logger.error("Failed to load options for action '\(action.title)': \(error)")
                }
            }

            // Sort options alphabetically
            loadedOptions.sort()

            DispatchQueue.main.async {
                self.options = loadedOptions
                self.isLoadingOptions = false
            }
        }
    }

    /// Recursively extracts names from a dictionary
    /// - Parameters:
    ///   - dict: The dictionary to extract from
    ///   - options: The array to add names to
    private func extractNames(from dict: [String: Any], into options: inout [String]) {
        // Check if this dictionary has a "name" key
        if let name = dict["name"] as? String {
            options.append(name)
        }

        // Recursively check all values
        for (_, value) in dict {
            if let nestedDict = value as? [String: Any] {
                extractNames(from: nestedDict, into: &options)
            } else if let array = value as? [Any] {
                for item in array {
                    if let nestedDict = item as? [String: Any] {
                        extractNames(from: nestedDict, into: &options)
                    }
                }
            }
        }
    }

    /// Executes an action for the selected option
    /// - Parameter option: The selected option
    private func executeAction(for option: String) {
        logger.debug("Executing action '\(action.title)' for option '\(option)'")

        // This is a simplified implementation
        // In a real app, this would depend on the action type

        if action.title.lowercased().contains("saml") {
            // Example: Run saml2aws login command
            DispatchQueue.global(qos: .userInitiated).async {
                let command = "saml2aws login --profile=\(option)"
                let (_, error, exitCode) = Process.shell(command)

                if exitCode != 0 {
                    logger.error("Failed to execute SAML command: \(error)")
                } else {
                    logger.debug("Successfully executed SAML command")
                }
            }
        }
    }
}

/// Errors that can occur when working with custom actions
enum CustomActionError: Error, LocalizedError {
    case fileNotFound(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        CustomActionView(action: CustomAction.urlAction(
            title: "JumpCloud",
            help: "Open JumpCloud",
            url: URL(string: "https://console.jumpcloud.com")!
        ))

        CustomActionView(action: CustomAction.dropdownAction(
            title: "SAML Profiles",
            help: "List of SAML Profiles",
            filePath: "~/.saml2aws",
            pathExpression: "$..name",
            parser: .toml
        ))
    }
    .padding()
}
