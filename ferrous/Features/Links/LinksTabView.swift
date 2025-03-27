//
//  LinksTabView.swift
//  ferrous
//
//  Created by Raghav Tandon on 21.03.25.
//

import SwiftUI

/// Tab view for links and version info
struct LinksTabView: View {
    @ObservedObject private var viewModel = MainMenuViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Version Info Section
            VStack(alignment: .leading, spacing: 4) {
                Text("App Version")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 4)
                
                VStack(spacing: 2) {
                    HStack {
                        Text("Current: \(Constants.version)")
                            .font(.system(size: 12))
                        
                        Spacer()
                    }
                    
                    if viewModel.updateAvailable, let releaseURL = viewModel.releaseURL {
                        HStack {
                            Text("Latest: \(viewModel.latestVersion ?? "Unknown")")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                                
                            Spacer()
                            
                            Button(action: {
                                NSWorkspace.shared.open(releaseURL)
                            }) {
                                Text("Update Available")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Links Section
            if !viewModel.customLinks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Links")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.vertical, 4)
                    
                    ForEach(viewModel.customLinks) { link in
                        Button(action: {
                            if let url = URL(string: link.url) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text(link.name)
                                    .font(.system(size: 11))
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Custom Actions Section
            if !viewModel.customActions.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actions")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.vertical, 4)
                    
                    ForEach(viewModel.customActions) { action in
                        CustomActionView(action: action)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    LinksTabView()
        .padding()
        .frame(width: 300)
}
