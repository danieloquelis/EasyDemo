//
//  WindowSelectionView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// View for selecting a window to record
struct WindowSelectionView: View {
    @StateObject private var viewModel = WindowSelectionViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Select Window to Record")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose any window on your screen to start recording")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)

            // Permission check
            if !viewModel.windowCapture.hasScreenRecordingPermission {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Screen Recording Permission Required")
                        .font(.headline)

                    Text("Please grant screen recording permission to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Grant Permission") {
                        Task {
                            await viewModel.windowCapture.requestScreenRecordingPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
            } else {
                // Window list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.windowCapture.availableWindows) { window in
                            WindowRowView(window: window, isSelected: viewModel.selectedWindow?.id == window.id)
                                .onTapGesture {
                                    viewModel.selectWindow(window)
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                // Refresh button
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await viewModel.refreshWindows()
                        }
                    } label: {
                        Label("Refresh Windows", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshing)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

/// Row view for displaying window information
struct WindowRowView: View {
    let window: WindowInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Window icon
            Image(systemName: "macwindow")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 40, height: 40)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            // Window info
            VStack(alignment: .leading, spacing: 4) {
                Text(window.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                HStack(spacing: 12) {
                    Label(
                        "\(Int(window.bounds.width)) × \(Int(window.bounds.height))",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                    .font(.caption)

                    Label("Layer \(window.layer)", systemImage: "square.stack")
                        .font(.caption)
                }
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    WindowSelectionView()
}
