//
//  RecordingCompletedView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI
import AVKit

/// View shown after recording is completed
struct RecordingCompletedView: View {
    let result: RecordingResult
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recording Complete")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Saved to Movies folder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    NSWorkspace.shared.selectFile(
                        result.fileURL.path,
                        inFileViewerRootedAtPath: result.fileURL.deletingLastPathComponent().path
                    )
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    NSWorkspace.shared.open(result.fileURL)
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
        .frame(width: 700)
        .onAppear {
            player = AVPlayer(url: result.fileURL)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
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
