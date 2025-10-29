//
//  RecordingConfiguration.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import CoreGraphics
import AVFoundation

/// Configuration for recording settings
struct RecordingConfiguration {
    let window: WindowInfo
    let background: BackgroundStyle
    let webcam: WebcamConfiguration
    let resolution: Resolution
    let frameRate: Int
    let codec: VideoCodec
    let outputURL: URL

    enum Resolution: String, CaseIterable, Identifiable {
        case hd1080 = "1080p HD"
        case hd1440 = "1440p QHD"
        case uhd4k = "4K UHD"
        case original = "Original"

        var id: String { rawValue }

        var dimensions: CGSize? {
            switch self {
            case .hd1080:
                return CGSize(width: 1920, height: 1080)
            case .hd1440:
                return CGSize(width: 2560, height: 1440)
            case .uhd4k:
                return CGSize(width: 3840, height: 2160)
            case .original:
                return nil
            }
        }
    }

    enum VideoCodec: String, CaseIterable, Identifiable {
        case h264 = "H.264"
        case hevc = "HEVC (H.265)"
        case prores = "ProRes 422"

        var id: String { rawValue }

        var avCodecType: AVVideoCodecType {
            switch self {
            case .h264:
                return .h264
            case .hevc:
                return .hevc
            case .prores:
                return .proRes422
            }
        }
    }

    static func `default`(
        window: WindowInfo,
        background: BackgroundStyle,
        webcam: WebcamConfiguration,
        resolution: Resolution = .original,
        frameRate: Int = 60,
        codec: VideoCodec = .h264,
        outputDirectory: URL? = nil
    ) -> RecordingConfiguration {
        // For sandboxed apps, we need to write to temp directory first
        // Then move to user-selected location after recording
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "Recording_\(timestamp).mov"

        let baseDirectory: URL
        if let customDir = outputDirectory {
            // User has selected a directory - we have security-scoped access
            baseDirectory = customDir
        } else {
            // Use temporary directory for recording
            // We'll prompt user to save after recording completes
            baseDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("EasyDemo", isDirectory: true)

            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }

        let outputURL = baseDirectory.appendingPathComponent(filename)

        return RecordingConfiguration(
            window: window,
            background: background,
            webcam: webcam,
            resolution: resolution,
            frameRate: frameRate,
            codec: codec,
            outputURL: outputURL
        )
    }
}
