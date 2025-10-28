//
//  RecordingResult.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation

/// Result of a completed recording
struct RecordingResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let duration: TimeInterval
    let fileSize: Int64
    let timestamp: Date

    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
