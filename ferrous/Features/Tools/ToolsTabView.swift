//
//  ToolsTabView.swift
//  ferrous
//
//  Created by Raghav Tandon on 21.03.25.
//


import SwiftUI

/// Tab view for tool statuses and Kubernetes contexts
struct ToolsTabView: View {
    @ObservedObject private var viewModel = MainMenuViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool Status Section
            VStack(alignment: .leading, spacing: 4) {
                Text("Tools Status")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 4)
                
                if viewModel.isLoadingTools {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if viewModel.toolStatuses.isEmpty {
                    Text("No tool statuses available")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.toolStatuses) { status in
                        ToolStatusRow(status: status)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Kubernetes Context Section
            VStack(alignment: .leading, spacing: 4) {
                Text("Kubernetes Context")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 4)
                
                if viewModel.isLoadingKubernetes {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    KubernetesView()
                }
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    ToolsTabView()
        .padding()
        .frame(width: 300)
}