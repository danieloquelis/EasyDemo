//
//  RecordingCompletedView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers
import AppKit

/// View shown after recording is completed
struct RecordingCompletedView: View {
    let result: RecordingResult
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var savedLocation: URL?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recording Complete")
                        .font(.title)
                        .fontWeight(.bold)

                    if let saved = savedLocation {
                        Text("Saved to: \(saved.lastPathComponent)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if result.fileURL.path.contains("tmp") || result.fileURL.path.contains("Temp") {
                        Text("Temporary location - use Save As to keep")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    } else {
                        Text("Saved to: \(result.fileURL.deletingLastPathComponent().lastPathComponent)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

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

            // Video preview
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 400)
                    .cornerRadius(12)
                    .onAppear {
                        player.play()
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 400)
                    .overlay(
                        ProgressView()
                    )
            }

            // Info
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.durationString)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("File Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.fileSizeString)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Format")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("MOV")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)

            // Actions
            HStack(spacing: 12) {
                Button {
                    let locationToShow = savedLocation ?? result.fileURL
                    NSWorkspace.shared.selectFile(
                        locationToShow.path,
                        inFileViewerRootedAtPath: locationToShow.deletingLastPathComponent().path
                    )
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    saveAs()
                } label: {
                    Label("Save As...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Button {
                    let locationToOpen = savedLocation ?? result.fileURL
                    NSWorkspace.shared.open(locationToOpen)
                } label: {
                    Label("Open Video", systemImage: "play.rectangle")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 700, height: 650)
        .onAppear {
            player = AVPlayer(url: result.fileURL)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

private extension RecordingCompletedView {
    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.movie]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = result.fileURL.lastPathComponent

        if panel.runModal() == .OK, let destinationURL = panel.url {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: result.fileURL, to: destinationURL)
                savedLocation = destinationURL
            } catch {
                NSLog("Failed to save: \(error.localizedDescription)")
            }
        }
    }
}

/// Document wrapper for video export
struct VideoDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.movie] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.mov")
        try data.write(to: tempURL)
        self.url = tempURL
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: url, options: .immediate)
    }
}

#Preview {
    RecordingCompletedView(
        result: RecordingResult(
            fileURL: URL(fileURLWithPath: "/tmp/test.mov"),
            duration: 125.5,
            fileSize: 15_000_000,
            timestamp: Date()
        )
    )
}
