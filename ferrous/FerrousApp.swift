import SwiftUI

/// The main entry point for the application
@main
struct FerrousApp: App {
    /// Application delegate for handling app lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}