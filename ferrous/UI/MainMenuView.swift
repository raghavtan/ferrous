import SwiftUI
import Combine

/// The main menu view displayed in the popover
struct MainMenuView: View {
    /// View model
    @StateObject private var viewModel = MainMenuViewModel.shared
    
    /// The currently selected refresh interval in seconds
    @AppStorage(Constants.UserDefaultsKey.refreshInterval)
    private var refreshInterval: Double = Constants.RefreshInterval.default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Tier Zero", isSelected: viewModel.selectedTab == 0) {
                    viewModel.selectedTab = 0
                }
                
                TabButton(title: "Tools", isSelected: viewModel.selectedTab == 1) {
                    viewModel.selectedTab = 1
                }
                
                TabButton(title: "Links", isSelected: viewModel.selectedTab == 2) {
                    viewModel.selectedTab = 2
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Main content area (scrollable)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Content based on selected tab
                    if viewModel.selectedTab == 0 {
                        // Tier Zero tab
                        TierZeroView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.selectedTab == 1 {
                        // Tools tab (Tool Status and Kubernetes)
                        ToolsTabView()
                            .frame(maxWidth: .infinity)
                    } else {
                        // Links tab (Version info and links)
                        LinksTabView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Bottom button row
            HStack {
                // Refresh interval menu
                Menu {
                    Button("30 seconds") {
                        refreshInterval = 30
                        viewModel.updateRefreshInterval(30)
                    }
                    Button("1 minute") {
                        refreshInterval = 60
                        viewModel.updateRefreshInterval(60)
                    }
                    Button("5 minutes") {
                        refreshInterval = 300
                        viewModel.updateRefreshInterval(300)
                    }
                    Button("15 minutes") {
                        refreshInterval = 900
                        viewModel.updateRefreshInterval(900)
                    }
                } label: {
                    Label(formatInterval(refreshInterval), systemImage: "clock")
                        .font(.system(size: 12))
                }
                .menuStyle(.automatic)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                
                // Spacer to push buttons to sides
                Spacer()
                
                // Refresh button
                Button(action: {
                    viewModel.refreshAll()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                // Quit button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 300, height: 450)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    /// Formats a time interval in seconds to a human-readable string
    /// - Parameter seconds: The time interval in seconds
    /// - Returns: A formatted string
    private func formatInterval(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }
}
