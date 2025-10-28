//
//  WindowPreview.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import SwiftUI
import ScreenCaptureKit
import Combine
import CoreMedia

/// Service for rendering window previews with backgrounds
@MainActor
class WindowPreview: NSObject, ObservableObject, SCStreamOutput {
    @Published var previewImage: CGImage?
    @Published var isCapturing = false

    private var stream: SCStream?
    private var continuation: CheckedContinuation<CGImage?, Never>?

    /// Capture a single frame from a window for preview
    func capturePreview(window: WindowInfo) async {
        guard !isCapturing else { return }
        isCapturing = true

        defer { isCapturing = false }

        do {
            let content = try await SCShareableContent.current

            // Find the SCWindow matching our WindowInfo
            guard let scWindow = content.windows.first(where: { $0.windowID == window.id }) else {
                print("Window not found")
                return
            }

            // Create filter for this specific window
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)

            // Configure stream for single frame capture
            let config = SCStreamConfiguration()
            config.width = Int(window.bounds.width)
            config.height = Int(window.bounds.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false
            config.captureResolution = .best
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            // Create stream
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            self.stream = stream

            // Add output handler
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

            // Start capture and wait for first frame
            try await stream.startCapture()

            // Wait for frame with timeout
            let image = await withCheckedContinuation { continuation in
                self.continuation = continuation

                // Timeout after 5 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if self.continuation != nil {
                        self.continuation?.resume(returning: nil)
                        self.continuation = nil
                    }
                }
            }

            // Stop capture
            try await stream.stopCapture()
            self.stream = nil

            // Update preview image
            if let image = image {
                self.previewImage = image
            }
        } catch {
            print("Failed to capture preview: \(error)")
        }
    }

    // MARK: - SCStreamOutput

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        // Convert to CGImage
        if let cgImage = createCGImage(from: imageBuffer) {
            // Resume continuation with the captured frame
            if let continuation = continuation {
                self.continuation = nil
                continuation.resume(returning: cgImage)
            }
        }
    }

    /// Convert CVPixelBuffer to CGImage
    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Stop any ongoing capture
    func stopCapture() async {
        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                print("Failed to stop capture: \(error)")
            }
        }
        stream = nil
    }
}
