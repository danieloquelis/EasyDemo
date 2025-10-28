//
//  SetupView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// Main setup view orchestrating window selection, background choice, and preview
struct SetupView: View {
    @State private var selectedWindow: WindowInfo?
    @State private var selectedBackground: BackgroundStyle = .solidColor(.black)
    @State private var showingWindowSelector = true
    @StateObject private var recordingEngine = RecordingEngine()

    var body: some View {
        NavigationSplitView {
            // Sidebar with setup options
            setupSidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            // Main preview area
            if let window = selectedWindow {
                WindowPreviewView(
                    window: window,
                    backgroundStyle: selectedBackground
                )
                .navigationTitle("Preview")
            } else {
                emptyPreviewState
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var setupSidebar: some View {
        List {
            Section("Window Selection") {
                if let window = selectedWindow {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(window.displayName)
                                .font(.headline)

                            Text("\(Int(window.bounds.width)) × \(Int(window.bounds.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Change") {
                            showingWindowSelector = true
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button("Select Window") {
                        showingWindowSelector = true
                    }
                }
            }

            if selectedWindow != nil {
                Section("Background") {
                    BackgroundSelectionView(selectedBackground: $selectedBackground)
                }

                Section("Recording") {
                    if recordingEngine.isRecording {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)

                                Text("Recording")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }

                            Text(formatDuration(recordingEngine.recordingDuration))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)

                            Button {
                                Task {
                                    await recordingEngine.stopRecording()
                                }
                            } label: {
                                Label("Stop Recording", systemImage: "stop.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Button {
                            if let window = selectedWindow {
                                let config = RecordingConfiguration.default(
                                    window: window,
                                    background: selectedBackground
                                )
                                Task {
                                    do {
                                        try await recordingEngine.startRecording(configuration: config)
                                    } catch {
                                        print("Failed to start recording: \(error)")
                                    }
                                }
                            }
                        } label: {
                            Label("Start Recording", systemImage: "record.circle")
                        }
                        .disabled(selectedWindow == nil)
                    }
                }
            }
        }
        .navigationTitle("Setup")
        .sheet(isPresented: $showingWindowSelector) {
            WindowSelectorSheet(selectedWindow: $selectedWindow)
        }
    }

    private var emptyPreviewState: some View {
        VStack(spacing: 20) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Select a window to preview")
                .font(.title2)
                .foregroundColor(.secondary)

            Button("Choose Window") {
                showingWindowSelector = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Sheet for window selection
struct WindowSelectorSheet: View {
    @Binding var selectedWindow: WindowInfo?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WindowSelectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Window")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Window list
            WindowSelectionView()
                .environmentObject(viewModel)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Select") {
                    selectedWindow = viewModel.selectedWindow
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedWindow == nil)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
    }
}

#Preview {
    SetupView()
}
