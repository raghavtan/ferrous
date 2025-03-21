import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// Returns a human-readable string representation of the time elapsed since this date.
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day, .weekOfMonth], from: self, to: now)

        if let week = components.weekOfMonth, week >= 1 {
            return "\(week)w ago"
        } else if let day = components.day, day >= 1 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour >= 1 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute >= 1 {
            return "\(minute)m ago"
        } else if let second = components.second, second >= 3 {
            return "\(second)s ago"
        } else {
            return "just now"
        }
    }
}

// MARK: - Process Extensions

extension Process {
    /// Executes a shell command and returns the output, error, and exit code.
    @discardableResult
    static func shell(_ command: String) -> (output: String, error: String, exitCode: Int32) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ("", "\(error)", 1)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return (output, error, task.terminationStatus)
    }
}

// MARK: - Result Extensions

extension Result where Success == Void {
    /// A successful result containing Void
    static var success: Result<Void, Failure> {
        return .success(())
    }
}

// MARK: - Color Extensions

extension Color {
    /// Returns a color based on a status (success, warning, error)
    static func status(_ status: StatusType) -> Color {
        switch status {
        case .success:
            return .green
        case .warning:
            return .yellow
        case .error:
            return .red
        case .neutral:
            return .gray
        }
    }

    enum StatusType {
        case success
        case warning
        case error
        case neutral
    }
}

// MARK: - String Extensions

extension String {
    /// Returns a version of the string with the first letter capitalized
    var capitalizingFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }

    /// Truncates the string to the specified length and adds an ellipsis if truncated
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Check if a directory exists, and create it if it doesn't
    func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if !fileExists(atPath: url.path, isDirectory: &isDirectory) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        } else if !isDirectory.boolValue {
            throw NSError(domain: "FileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Path exists but is not a directory: \(url.path)"])
        }
    }
}