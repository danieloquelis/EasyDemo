//
//  WindowSelectionView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// View for selecting a source (window or display) to record
struct WindowSelectionView: View {
    @Binding var selectedSource: CaptureSource?
    @StateObject private var viewModel = WindowSelectionViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Select Source to Record")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose a window or screen to start recording")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)

            // Loading, permission check, or source list
            if viewModel.windowCapture.isCheckingPermission {
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
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Screen Recording Permission Required")
                        .font(.headline)

                    Text("Grant screen recording permission in System Settings, then switch back here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Open System Settings") {
                        Task {
                            await viewModel.requestPermissionAndLoadSources()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
            } else {
                // Capture mode picker
                Picker("Mode", selection: $viewModel.captureMode) {
                    ForEach(WindowSelectionViewModel.CaptureMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if viewModel.isRefreshing && viewModel.windowCapture.availableWindows.isEmpty && viewModel.windowCapture.availableDisplays.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()

                        Text("Loading sources...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Source list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.captureMode == .windows {
                                ForEach(viewModel.windowCapture.availableWindows) { window in
                                    let source = CaptureSource.window(window)
                                    WindowRowView(window: window, isSelected: selectedSource == source)
                                        .onTapGesture {
                                            selectedSource = source
                                        }
                                }
                            } else {
                                ForEach(viewModel.windowCapture.availableDisplays) { display in
                                    let source = CaptureSource.display(display)
                                    DisplayRowView(display: display, isSelected: selectedSource == source)
                                        .onTapGesture {
                                            selectedSource = source
                                        }
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
                                await viewModel.refreshSources()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
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
                        "\(Int(window.bounds.width)) x \(Int(window.bounds.height))",
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
            thumbnail = nil
        }
    }
}

/// Row view for displaying display information
struct DisplayRowView: View {
    let display: DisplayInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 80, height: 60)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(display.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(
                        "\(display.width) x \(display.height)",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                    .font(.caption)

                    if CGDisplayIsMain(display.id) != 0 {
                        Text("Main")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()

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
    WindowSelectionView(selectedSource: .constant(nil))
}
