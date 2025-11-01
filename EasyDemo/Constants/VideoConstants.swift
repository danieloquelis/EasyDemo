import Foundation
import CoreGraphics

enum VideoConstants {
    enum Resolution {
        static let hd1080 = CGSize(width: 1920, height: 1080)
        static let hd1440 = CGSize(width: 2560, height: 1440)
        static let uhd4k = CGSize(width: 3840, height: 2160)
    }

    enum FrameRate {
        static let standard: Int = 30
        static let cinematic: Int = 60
    }

    enum Bitrate {
        static let minimum: Int = 30_000_000
        static let bitsPerPixel4K: CGFloat = 0.2
        static let bitsPerPixelHD: CGFloat = 0.15
    }

    enum Webcam {
        static let captureWidth: Int = 1920
        static let captureHeight: Int = 1080
        static let defaultPosition: CGPoint = CGPoint(x: 0.85, y: 0.85)
    }
}
