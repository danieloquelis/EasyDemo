import Foundation
import CoreGraphics
import AVFoundation

struct RecordingConfiguration {
    let window: WindowInfo
    let background: BackgroundStyle
    let webcam: WebcamConfiguration
    let resolution: Resolution
    let frameRate: Int
    let codec: VideoCodec
    let outputURL: URL
    let windowScale: Double

    enum Resolution: String, CaseIterable, Identifiable {
        case hd1080 = "1080p HD"
        case hd1440 = "1440p QHD"
        case uhd4k = "4K UHD"
        case original = "Original"

        var id: String { rawValue }

        var dimensions: CGSize? {
            switch self {
            case .hd1080:
                return VideoConstants.Resolution.hd1080
            case .hd1440:
                return VideoConstants.Resolution.hd1440
            case .uhd4k:
                return VideoConstants.Resolution.uhd4k
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
        frameRate: Int = VideoConstants.FrameRate.cinematic,
        codec: VideoCodec = .h264,
        outputDirectory: URL? = nil,
        windowScale: Double = 1.0
    ) -> RecordingConfiguration {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(StringConstants.Recording.fileNamePrefix)\(timestamp).\(StringConstants.Recording.fileExtension)"

        let baseDirectory: URL
        if let customDir = outputDirectory {
            baseDirectory = customDir
        } else {
            baseDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent(StringConstants.Path.appFolder, isDirectory: true)
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
            outputURL: outputURL,
            windowScale: windowScale
        )
    }
}
