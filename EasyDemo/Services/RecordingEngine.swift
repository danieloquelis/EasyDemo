//
//  RecordingEngine.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreGraphics
import AppKit
import Combine
import SwiftUI

/// Engine responsible for recording window capture with composition
@MainActor
class RecordingEngine: NSObject, ObservableObject, SCStreamOutput {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: Error?

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var configuration: RecordingConfiguration?
    private var startTime: CMTime?
    private var frameCount: Int64 = 0
    private var durationTimer: Timer?
    private var captureScaleFactor: CGFloat = 2.0  // Store the actual scale factor from SCContentFilter
    private var targetOutputSize: CGSize = .zero  // Target output size for upscaling

    // Background rendering
    private let ciContext = CIContext()

    // Webcam capture
    private var webcamCapture: WebcamCapture?

    /// Start recording with the given configuration
    func startRecording(configuration: RecordingConfiguration) async throws {
        guard !isRecording else { return }

        self.configuration = configuration
        self.isRecording = true
        self.frameCount = 0
        self.startTime = nil
        self.recordingDuration = 0

        // Get the scale factor FIRST before setting up the writer
        // We need this to calculate the correct output dimensions
        let content = try await SCShareableContent.current
        guard let scWindow = content.windows.first(where: {
            $0.windowID == configuration.window.id
        }) else {
            throw RecordingError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        self.captureScaleFactor = CGFloat(filter.pointPixelScale)

        print("🎥 Recording Setup:")
        print("  - Window bounds (points): \(configuration.window.bounds.size)")
        print("  - Scale factor: \(captureScaleFactor)x")
        print("  - Expected capture size: \(Int(configuration.window.bounds.width * captureScaleFactor))×\(Int(configuration.window.bounds.height * captureScaleFactor)) px")

        // Set up AVAssetWriter (now has correct scale factor)
        try setupAssetWriter(configuration: configuration)

        // Set up SCStream
        try await setupStream(configuration: configuration, filter: filter)

        // Set up webcam if enabled
        if configuration.webcam.isEnabled {
            let webcam = WebcamCapture()
            try await webcam.startCapture()
            self.webcamCapture = webcam
        }

        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            let currentTime = CMTime(
                seconds: CACurrentMediaTime(),
                preferredTimescale: 600
            )
            self.recordingDuration = CMTimeGetSeconds(CMTimeSubtract(currentTime, startTime))
        }
    }

    /// Stop recording and finalize video file
    func stopRecording() async -> RecordingResult? {
        guard isRecording else { return nil }

        let finalDuration = recordingDuration
        let outputURL = configuration?.outputURL

        durationTimer?.invalidate()
        durationTimer = nil

        // Stop webcam
        webcamCapture?.stopCapture()
        webcamCapture = nil

        // Stop stream
        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                print("Error stopping stream: \(error)")
            }
        }

        // Finalize asset writer
        if let videoInput = videoInput {
            videoInput.markAsFinished()
        }

        if let assetWriter = assetWriter {
            await assetWriter.finishWriting()
        }

        self.stream = nil
        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil
        self.startTime = nil
        self.isRecording = false

        // Create result
        if let url = outputURL {
            print("Recording saved to: \(url.path)")

            // Wait a moment for file system to flush
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Get file size
            let fileSize: Int64
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                fileSize = size
                print("File size: \(size) bytes")
            } else {
                print("Warning: Could not get file size for \(url.path)")
                fileSize = 0
            }

            return RecordingResult(
                fileURL: url,
                duration: finalDuration,
                fileSize: fileSize,
                timestamp: Date()
            )
        }

        return nil
    }

    // MARK: - Setup

    private func setupAssetWriter(configuration: RecordingConfiguration) throws {
        let writer = try AVAssetWriter(url: configuration.outputURL, fileType: .mov)

        // Determine output size - MUST account for pixel scale and margins
        // The actual frames we compose will be at native pixel resolution with margins added
        let outputSize: CGSize
        if let resolution = configuration.resolution.dimensions {
            outputSize = resolution
        } else {
            // Calculate the actual pixel dimensions we'll be composing
            // Window bounds are in points, multiply by scale factor for pixels
            let windowPixelWidth = configuration.window.bounds.width * captureScaleFactor
            let windowPixelHeight = configuration.window.bounds.height * captureScaleFactor

            // Add margins (80pt on each side = 160pt total, scaled to pixels)
            let marginInPoints: CGFloat = 80
            let marginInPixels = marginInPoints * 2 * captureScaleFactor

            outputSize = CGSize(
                width: windowPixelWidth + marginInPixels,
                height: windowPixelHeight + marginInPixels
            )
        }

        // Store the target output size for upscaling in composeFrame
        self.targetOutputSize = outputSize

        print("  - Output video size: \(Int(outputSize.width))×\(Int(outputSize.height)) px")

        // Configure video settings with high quality for professional output
        // Calculate adaptive bitrate based on resolution (higher res = higher bitrate)
        let pixelCount = outputSize.width * outputSize.height
        let is4K = pixelCount >= 3840 * 2160 * 0.9  // ~4K resolution
        let bitsPerPixel: CGFloat = is4K ? 0.2 : 0.15  // Higher quality for 4K
        let targetBitrate = Int(pixelCount * bitsPerPixel * CGFloat(configuration.frameRate))

        // Recommend HEVC for 4K recordings (better compression)
        if is4K && configuration.codec == .h264 {
            print("  ⚠️  Tip: Use HEVC codec for better 4K compression and quality")
        }

        print("  - Target bitrate: \(targetBitrate / 1_000_000) Mbps")

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.codec.avCodecType,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(targetBitrate, 30_000_000),  // Minimum 30 Mbps for high quality
                AVVideoMaxKeyFrameIntervalKey: configuration.frameRate * 2,  // Keyframe every 2 seconds
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoQualityKey: 0.9  // High quality (0.0-1.0 scale)
            ]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        // Configure pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        } else {
            throw RecordingError.cannotAddVideoInput
        }

        self.assetWriter = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor

        writer.startWriting()
        let startTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
        writer.startSession(atSourceTime: startTime)
        self.startTime = startTime
    }

    private func setupStream(configuration: RecordingConfiguration, filter: SCContentFilter) async throws {
        // Scale factor already stored in startRecording()

        let streamConfig = SCStreamConfiguration()

        // CRITICAL: Use filter's pointPixelScale for TRUE native resolution capture
        // This is the authoritative scale factor from ScreenCaptureKit itself
        // pointPixelScale accounts for Retina displays (typically 2.0) and the actual content scale
        // contentRect gives us the logical dimensions, multiply by pointPixelScale for physical pixels
        streamConfig.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        streamConfig.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))

        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = true
        streamConfig.captureResolution = .best
        streamConfig.scalesToFit = false  // Don't scale down - capture at full resolution
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

        self.stream = stream
        try await stream.startCapture()
    }

    // MARK: - SCStreamOutput

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard let configuration = configuration,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        // Compose frame with background
        if let composedBuffer = composeFrame(imageBuffer, configuration: configuration) {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            adaptor.append(composedBuffer, withPresentationTime: presentationTime)
            frameCount += 1

            // Debug: Log first frame dimensions
            if frameCount == 1 {
                let bufWidth = CVPixelBufferGetWidth(composedBuffer)
                let bufHeight = CVPixelBufferGetHeight(composedBuffer)
                print("  - First frame composed: \(bufWidth)×\(bufHeight) px")
            }
        }
    }

    // MARK: - Frame Composition

    private func composeFrame(
        _ windowBuffer: CVPixelBuffer,
        configuration: RecordingConfiguration
    ) -> CVPixelBuffer? {
        let windowWidth = CVPixelBufferGetWidth(windowBuffer)
        let windowHeight = CVPixelBufferGetHeight(windowBuffer)

        // Add margins to show background (same as preview - 80px margin in points)
        // Use the exact scale factor from SCContentFilter for pixel-perfect composition
        let marginInPoints: CGFloat = 80  // 80pt on each side
        let marginInPixels = Int(marginInPoints * 2 * captureScaleFactor)  // *2 for both sides

        // Calculate native composition size (before any upscaling)
        let nativeWidth = windowWidth + marginInPixels
        let nativeHeight = windowHeight + marginInPixels

        // Determine final output dimensions (may be upscaled for 4K)
        let finalWidth: Int
        let finalHeight: Int
        let needsUpscaling: Bool

        if targetOutputSize != .zero &&
           (Int(targetOutputSize.width) != nativeWidth || Int(targetOutputSize.height) != nativeHeight) {
            // User selected a specific resolution (e.g., 4K) - upscale to fit
            finalWidth = Int(targetOutputSize.width)
            finalHeight = Int(targetOutputSize.height)
            needsUpscaling = true
        } else {
            // Use native resolution
            finalWidth = nativeWidth
            finalHeight = nativeHeight
            needsUpscaling = false
        }

        // Create output pixel buffer at final size
        var outputBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: finalWidth,
            kCVPixelBufferHeightKey as String: finalHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            finalWidth,
            finalHeight,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &outputBuffer
        )

        guard let output = outputBuffer else { return nil }

        // Create background image at native composition size first
        let nativeBackgroundImage = createBackgroundImage(
            size: CGSize(width: nativeWidth, height: nativeHeight),
            style: configuration.background
        )

        // Window image centered on canvas
        let windowImage = CIImage(cvPixelBuffer: windowBuffer)
        let xOffset = CGFloat(marginInPixels) / 2
        let yOffset = CGFloat(marginInPixels) / 2
        let centeredWindow = windowImage.transformed(
            by: CGAffineTransform(translationX: xOffset, y: yOffset)
        )

        // Composite: window over background
        var composited = centeredWindow.composited(over: nativeBackgroundImage)

        // Add webcam overlay if enabled (at native size)
        if configuration.webcam.isEnabled, let webcamFrame = webcamCapture?.currentFrame {
            let webcamOverlay = createWebcamOverlay(
                webcamFrame: webcamFrame,
                configuration: configuration.webcam,
                canvasSize: CGSize(width: nativeWidth, height: nativeHeight)
            )
            composited = webcamOverlay.composited(over: composited)
        }

        // Upscale to target resolution if needed (e.g., for 4K output)
        if needsUpscaling {
            // Calculate scale factor to fit content within target resolution while preserving aspect ratio
            let nativeAspect = CGFloat(nativeWidth) / CGFloat(nativeHeight)
            let targetAspect = CGFloat(finalWidth) / CGFloat(finalHeight)

            let scaledWidth: CGFloat
            let scaledHeight: CGFloat

            if nativeAspect > targetAspect {
                // Native is wider - fit to width
                scaledWidth = CGFloat(finalWidth)
                scaledHeight = scaledWidth / nativeAspect
            } else {
                // Native is taller - fit to height
                scaledHeight = CGFloat(finalHeight)
                scaledWidth = scaledHeight * nativeAspect
            }

            let scale = scaledWidth / CGFloat(nativeWidth)

            // Apply Lanczos scale filter for high-quality upscaling
            let scaled = composited.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scale,
                "inputAspectRatio": 1.0
            ])

            // Center the scaled image on a background that fills the target resolution
            let xOffset = (CGFloat(finalWidth) - scaledWidth) / 2
            let yOffset = (CGFloat(finalHeight) - scaledHeight) / 2

            let centered = scaled.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))

            // Create a black background at target resolution
            let targetBackground = CIImage(color: CIColor.black)
                .cropped(to: CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))

            // Composite centered content over black background
            composited = centered.composited(over: targetBackground)

            if frameCount == 1 {
                print("  - Upscaling: \(nativeWidth)×\(nativeHeight) → \(Int(scaledWidth))×\(Int(scaledHeight)) centered in \(finalWidth)×\(finalHeight) (Lanczos, aspect preserved)")
            }
        }

        // Render to output buffer
        ciContext.render(composited, to: output)

        return output
    }

    private func createBackgroundImage(size: CGSize, style: BackgroundStyle) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)

        switch style {
        case .solidColor(let color):
            if let cgColor = color.cgColor {
                return CIImage(color: CIColor(cgColor: cgColor)).cropped(to: rect)
            }
            return CIImage(color: CIColor.black).cropped(to: rect)

        case .gradient(let colors, let startPoint, let endPoint):
            // Create gradient using CIFilter
            let ciColors = colors.compactMap { $0.cgColor }.map { CIColor(cgColor: $0) }
            if ciColors.count >= 2 {
                let startVector = CIVector(
                    x: startPoint.x * size.width,
                    y: (1 - startPoint.y) * size.height
                )
                let endVector = CIVector(
                    x: endPoint.x * size.width,
                    y: (1 - endPoint.y) * size.height
                )

                if let filter = CIFilter(name: "CILinearGradient") {
                    filter.setValue(ciColors[0], forKey: "inputColor0")
                    filter.setValue(ciColors[1], forKey: "inputColor1")
                    filter.setValue(startVector, forKey: "inputPoint0")
                    filter.setValue(endVector, forKey: "inputPoint1")

                    if let output = filter.outputImage {
                        return output.cropped(to: rect)
                    }
                }
            }
            return CIImage(color: CIColor.black).cropped(to: rect)

        case .blur:
            // TODO: Implement wallpaper blur
            return CIImage(color: CIColor.gray).cropped(to: rect)

        case .image(let url):
            if let nsImage = NSImage(contentsOf: url),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let ciImage = CIImage(cgImage: cgImage)
                // Scale to fit
                let scale = max(size.width / ciImage.extent.width, size.height / ciImage.extent.height)
                return ciImage
                    .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    .cropped(to: rect)
            }
            return CIImage(color: CIColor.black).cropped(to: rect)
        }
    }

    private func createWebcamOverlay(
        webcamFrame: CIImage,
        configuration: WebcamConfiguration,
        canvasSize: CGSize
    ) -> CIImage {
        // Scale webcam size and padding to match the native resolution canvas
        let size = configuration.size * captureScaleFactor
        let padding: CGFloat = 40 * captureScaleFactor

        // Scale webcam to fill the target size (aspect fill)
        let targetSize = CGSize(width: size, height: size)
        let webcamAspect = webcamFrame.extent.width / webcamFrame.extent.height
        let targetAspect = targetSize.width / targetSize.height

        var scale: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if webcamAspect > targetAspect {
            // Webcam is wider - fit height, crop width
            scale = targetSize.height / webcamFrame.extent.height
            offsetX = (webcamFrame.extent.width * scale - targetSize.width) / 2
        } else {
            // Webcam is taller - fit width, crop height
            scale = targetSize.width / webcamFrame.extent.width
            offsetY = (webcamFrame.extent.height * scale - targetSize.height) / 2
        }

        // Scale and center crop
        let scaledWebcam = webcamFrame
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: CGRect(
                x: offsetX,
                y: offsetY,
                width: targetSize.width,
                height: targetSize.height
            ))

        // Calculate position on canvas
        let position = configuration.position.offset(
            in: canvasSize,
            webcamSize: size,
            padding: padding
        )

        // Apply shape mask
        var maskedWebcam = scaledWebcam

        switch configuration.shape {
        case .circle:
            // Create circular mask with proper dimensions
            let maskRect = CGRect(origin: .zero, size: targetSize)

            if let radialFilter = CIFilter(name: "CIRadialGradient") {
                radialFilter.setValue(CIVector(x: targetSize.width/2, y: targetSize.height/2), forKey: "inputCenter")
                radialFilter.setValue(targetSize.width/2 - 1, forKey: "inputRadius0")  // Slightly smaller to avoid edge artifacts
                radialFilter.setValue(targetSize.width/2, forKey: "inputRadius1")
                radialFilter.setValue(CIColor.white, forKey: "inputColor0")
                radialFilter.setValue(CIColor.clear, forKey: "inputColor1")

                if let maskImage = radialFilter.outputImage?.cropped(to: maskRect) {
                    maskedWebcam = scaledWebcam.applyingFilter("CIBlendWithMask", parameters: [
                        kCIInputMaskImageKey: maskImage
                    ])
                }
            }

            // Add border if specified
            if configuration.borderWidth > 0 {
                if let borderFilter = CIFilter(name: "CIConstantColorGenerator") {
                    borderFilter.setValue(CIColor.white, forKey: kCIInputColorKey)
                    if let borderColor = borderFilter.outputImage {
                        // Create ring mask for border
                        if let borderMask = CIFilter(name: "CIRadialGradient") {
                            let innerRadius = targetSize.width/2 - configuration.borderWidth - 1
                            let outerRadius = targetSize.width/2 - 1
                            borderMask.setValue(CIVector(x: targetSize.width/2, y: targetSize.height/2), forKey: "inputCenter")
                            borderMask.setValue(innerRadius, forKey: "inputRadius0")
                            borderMask.setValue(outerRadius, forKey: "inputRadius1")
                            borderMask.setValue(CIColor.clear, forKey: "inputColor0")
                            borderMask.setValue(CIColor.white, forKey: "inputColor1")

                            if let borderMaskImage = borderMask.outputImage?.cropped(to: maskRect) {
                                let borderedColor = borderColor.applyingFilter("CIBlendWithMask", parameters: [
                                    kCIInputMaskImageKey: borderMaskImage
                                ])
                                maskedWebcam = borderedColor.composited(over: maskedWebcam)
                            }
                        }
                    }
                }
            }

        case .roundedRectangle, .squircle:
            // Keep rectangular for now - can add rounded corner filters later
            break
        }

        // Position the webcam overlay on canvas
        let positioned = maskedWebcam.transformed(
            by: CGAffineTransform(translationX: position.x, y: position.y)
        )

        return positioned
    }

    enum RecordingError: LocalizedError {
        case cannotAddVideoInput
        case windowNotFound

        var errorDescription: String? {
            switch self {
            case .cannotAddVideoInput:
                return "Failed to add video input to asset writer"
            case .windowNotFound:
                return "Selected window not found"
            }
        }
    }
}
