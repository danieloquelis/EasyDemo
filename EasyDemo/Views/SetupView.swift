//
//  SetupView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main setup view orchestrating window selection, background choice, and preview
struct SetupView: View {
    @State private var selectedWindow: WindowInfo?
    @State private var selectedBackground: BackgroundStyle = .solidColor(Color(red: 1.0, green: 0.55, blue: 0.0))
    @State private var webcamConfig = WebcamConfiguration.default
    @State private var selectedResolution: RecordingConfiguration.Resolution = .original
    @State private var selectedCodec: RecordingConfiguration.VideoCodec = .h264
    @State private var frameRate: Int = 60
    @State private var windowScale: Double = 0.8  // 80% by default
    @State private var showingWindowSelector = true
    @State private var expandedSection: SidebarSection? = nil
    @State private var recordingResult: RecordingResult?
    @State private var outputDirectory: URL?
    @State private var showingFolderPicker = false
    @StateObject private var recordingEngine = RecordingEngine()

    enum SidebarSection: Hashable {
        case windowSize
        case background
        case webcam
        case advanced
        case output
    }

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
                    backgroundStyle: selectedBackground,
                    webcamConfig: webcamConfig,
                    windowScale: windowScale
                )
                .id(window.id)  // Force recreation when window changes
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
                        .disabled(recordingEngine.isRecording)
                    }
                } else {
                    Button("Select Window") {
                        showingWindowSelector = true
                    }
                    .disabled(recordingEngine.isRecording)
                }
            }

            if selectedWindow != nil {
                Section("Window Size") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scale:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(windowScale * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $windowScale, in: 0.2...1.0, step: 0.05)
                            .tint(.accentColor)
                            .disabled(recordingEngine.isRecording)

                        HStack {
                            Text("20%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("100%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        expandedSection = expandedSection == .background ? nil : .background
                    } label: {
                        HStack {
                            Label {
                                Text("Background")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: expandedSection == .background ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(expandedSection == .background ? 0 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(recordingEngine.isRecording)

                    if expandedSection == .background {
                        BackgroundSelectionView(selectedBackground: $selectedBackground)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 8)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .disabled(recordingEngine.isRecording)
                    }
                }

                Section {
                    Button {
                        expandedSection = expandedSection == .webcam ? nil : .webcam
                    } label: {
                        HStack {
                            Label {
                                Text("Webcam Overlay")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "video.circle")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: expandedSection == .webcam ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(recordingEngine.isRecording)

                    if expandedSection == .webcam {
                        WebcamSettingsView(configuration: $webcamConfig)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 8)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .disabled(recordingEngine.isRecording)
                    }
                }

                Section {
                    Button {
                        expandedSection = expandedSection == .advanced ? nil : .advanced
                    } label: {
                        HStack {
                            Label {
                                Text("Advanced Quality Settings")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "gearshape.2")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: expandedSection == .advanced ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(recordingEngine.isRecording)

                    if expandedSection == .advanced {
                        RecordingSettingsView(
                            selectedResolution: $selectedResolution,
                            selectedCodec: $selectedCodec,
                            frameRate: $frameRate
                        )
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 8)
                        .background(Color(.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                        .disabled(recordingEngine.isRecording)
                    }
                }

                Section {
                    Button {
                        expandedSection = expandedSection == .output ? nil : .output
                    } label: {
                        HStack {
                            Label {
                                Text("Output")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: expandedSection == .output ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(recordingEngine.isRecording)

                    if expandedSection == .output {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Save Location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button {
                                showingFolderPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text(outputDirectory?.lastPathComponent ?? "Movies/EasyDemo")
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                            .disabled(recordingEngine.isRecording)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 8)
                        .background(Color(.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
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
                                    let result = await recordingEngine.stopRecording()
                                    recordingResult = result
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
                                    background: selectedBackground,
                                    webcam: webcamConfig,
                                    resolution: selectedResolution,
                                    frameRate: frameRate,
                                    codec: selectedCodec,
                                    outputDirectory: outputDirectory,
                                    windowScale: windowScale
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
        .sheet(item: $recordingResult) { result in
            RecordingCompletedView(result: result)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    outputDirectory = url
                }
            case .failure(let error):
                print("Failed to select folder: \(error)")
            }
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
    @State private var tempSelection: WindowInfo?

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
            WindowSelectionView(selectedWindow: $tempSelection)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Select") {
                    selectedWindow = tempSelection
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tempSelection == nil)
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
