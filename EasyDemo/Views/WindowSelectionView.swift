//
//  WindowSelectionView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// View for selecting a window to record
struct WindowSelectionView: View {
    @Binding var selectedWindow: WindowInfo?
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

            // Loading, permission check, or window list
            if viewModel.windowCapture.isCheckingPermission {
                // Show loading state while checking permissions
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()

                    Text("Checking permissions...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else if !viewModel.windowCapture.hasScreenRecordingPermission {
                // Show permission request UI if denied
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
                // Window list or loading
                if viewModel.isRefreshing && viewModel.windowCapture.availableWindows.isEmpty {
                    // Show loading state while fetching windows for the first time
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()

                        Text("Loading windows...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Window list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.windowCapture.availableWindows) { window in
                                WindowRowView(window: window, isSelected: selectedWindow?.id == window.id)
                                    .onTapGesture {
                                        selectedWindow = window
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
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

/// Row view for displaying window information
struct WindowRowView: View {
    let window: WindowInfo
    let isSelected: Bool
    @StateObject private var windowCapture = WindowCapture()
    @State private var thumbnail: CGImage?

    var body: some View {
        HStack(spacing: 12) {
            // Window thumbnail
            if let thumbnail = thumbnail {
                Image(decorative: thumbnail, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 80, height: 60)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }

            // Window info
            VStack(alignment: .leading, spacing: 4) {
                Text(window.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(
                        "\(Int(window.bounds.width)) × \(Int(window.bounds.height))",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
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
        .task {
            thumbnail = await windowCapture.captureThumbnail(for: window)
        }
    }
}

#Preview {
    WindowSelectionView(selectedWindow: .constant(nil))
}
