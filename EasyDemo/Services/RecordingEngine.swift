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

    // Cache for webcam masks to avoid regenerating every frame
    private var cachedMask: CIImage?
    private var cachedMaskSize: CGSize = .zero
    private var cachedMaskShape: WebcamConfiguration.Shape?

    // Cache for custom background image to avoid repeated disk I/O
    private var cachedBackgroundImage: CIImage?
    private var cachedBackgroundURL: URL?

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

        // Window image with user-defined scale
        let windowImage = CIImage(cvPixelBuffer: windowBuffer)

        // Apply window scale (0.2 to 1.0)
        let windowScale = CGFloat(configuration.windowScale)
        let scaledWindow = windowImage.transformed(
            by: CGAffineTransform(scaleX: windowScale, y: windowScale)
        )

        // Center the scaled window on canvas
        let scaledWidth = windowImage.extent.width * windowScale
        let scaledHeight = windowImage.extent.height * windowScale
        let xOffset = (CGFloat(nativeWidth) - scaledWidth) / 2
        let yOffset = (CGFloat(nativeHeight) - scaledHeight) / 2
        let centeredWindow = scaledWindow.transformed(
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

        case .image(let url):
            // Check if we can use cached image
            let baseImage: CIImage?
            if let cachedImage = cachedBackgroundImage, cachedBackgroundURL == url {
                baseImage = cachedImage
            } else {
                // Load and cache the image
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                if let nsImage = NSImage(contentsOf: url),
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    baseImage = CIImage(cgImage: cgImage)
                    cachedBackgroundImage = baseImage
                    cachedBackgroundURL = url
                } else {
                    baseImage = nil
                }
            }

            if let ciImage = baseImage {
                // Scale to fit - use simpler scaling for better performance
                let scaleX = size.width / ciImage.extent.width
                let scaleY = size.height / ciImage.extent.height
                let scale = max(scaleX, scaleY)

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

        // Debug: Log webcam frame extent on first few frames
        if frameCount <= 3 {
            print("🎥 Frame \(frameCount): Webcam overlay")
            print("  - Webcam frame extent: \(webcamFrame.extent)")
            print("  - Canvas size: \(canvasSize)")
            print("  - Target webcam size: \(size)px")
            print("  - Configuration position: \(configuration.position.rawValue)")
        }

        // Scale webcam to fill the target size (aspect fill)
        let targetSize = CGSize(width: size, height: size)
        let webcamAspect = webcamFrame.extent.width / webcamFrame.extent.height
        let targetAspect = targetSize.width / targetSize.height

        var scale: CGFloat
        var cropRect: CGRect

        if webcamAspect > targetAspect {
            // Webcam is wider - fit height, crop width
            scale = targetSize.height / webcamFrame.extent.height
            let scaledWidth = webcamFrame.extent.width * scale
            let offsetX = (scaledWidth - targetSize.width) / 2
            cropRect = CGRect(
                x: offsetX,
                y: 0,
                width: targetSize.width,
                height: targetSize.height
            )
        } else {
            // Webcam is taller - fit width, crop height
            scale = targetSize.width / webcamFrame.extent.width
            let scaledHeight = webcamFrame.extent.height * scale
            let offsetY = (scaledHeight - targetSize.height) / 2
            cropRect = CGRect(
                x: 0,
                y: offsetY,
                width: targetSize.width,
                height: targetSize.height
            )
        }

        // Scale and center crop the webcam feed
        let scaledWebcam = webcamFrame
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: cropRect)
            // Move the cropped region to origin (0,0)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))

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
            // Use CICrop + CICircleSplashDistortion for simpler circular clipping
            // This is similar to how Loom/Screen Studio do it
            let maskRect = CGRect(origin: .zero, size: targetSize)

            // Check if we can reuse cached mask
            let mask: CIImage?
            if let cachedMask = cachedMask,
               cachedMaskSize == targetSize,
               cachedMaskShape == .circle {
                mask = cachedMask
            } else {
                // Create new mask and cache it
                let radius = min(targetSize.width, targetSize.height) / 2
                let centerX = targetSize.width / 2
                let centerY = targetSize.height / 2

                mask = CIFilter(name: "CIRadialGradient", parameters: [
                    "inputCenter": CIVector(x: centerX, y: centerY),
                    "inputRadius0": radius - 1,
                    "inputRadius1": radius,
                    "inputColor0": CIColor.white,
                    "inputColor1": CIColor.clear
                ])?.outputImage?.cropped(to: maskRect)

                cachedMask = mask
                cachedMaskSize = targetSize
                cachedMaskShape = .circle
            }

            if let mask = mask {
                // Create the masked webcam by blending
                let maskedImage = scaledWebcam
                    .cropped(to: maskRect)
                    .applyingFilter("CIBlendWithAlphaMask", parameters: [
                        "inputMaskImage": mask
                    ])

                // Add shadow to webcam (like Loom/Screen Studio)
                // Create shadow using CIGaussianBlur + offset
                // Reduced shadow radius for better performance
                let shadowRadius = 15.0 * captureScaleFactor  // Reduced from 30 for performance
                let shadowOffset = CGSize(width: 0, height: -10 * captureScaleFactor)
                let shadowOpacity: CGFloat = 0.6  // Slightly lighter shadow

                // Create a black version of the mask for the shadow
                let shadowMask = CIImage(color: CIColor.black).cropped(to: maskRect)
                    .applyingFilter("CIBlendWithAlphaMask", parameters: [
                        "inputMaskImage": mask
                    ])

                // Apply blur to create soft shadow
                let shadow = shadowMask
                    .applyingFilter("CIGaussianBlur", parameters: [
                        "inputRadius": shadowRadius
                    ])
                    .transformed(by: CGAffineTransform(translationX: shadowOffset.width, y: shadowOffset.height))
                    .applyingFilter("CIColorMatrix", parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: shadowOpacity)
                    ])

                // Composite: webcam over shadow
                maskedWebcam = maskedImage.composited(over: shadow)
            }

        case .roundedRectangle:
            // Create rounded rectangle mask using Core Graphics
            let maskRect = CGRect(origin: .zero, size: targetSize)
            let cornerRadius: CGFloat = 16 * captureScaleFactor

            // Check if we can reuse cached mask
            let mask: CIImage?
            if let cachedMask = cachedMask,
               cachedMaskSize == targetSize,
               cachedMaskShape == .roundedRectangle {
                mask = cachedMask
            } else {
                // Create new mask and cache it
                mask = createRoundedRectangleMask(size: targetSize, cornerRadius: cornerRadius)
                cachedMask = mask
                cachedMaskSize = targetSize
                cachedMaskShape = .roundedRectangle
            }

            if let mask = mask {
                if frameCount <= 3 {
                    print("  - Rounded rectangle mask created: extent=\(mask.extent)")
                }

                // Ensure webcam is cropped and positioned at origin
                let croppedWebcam = scaledWebcam.cropped(to: maskRect)
                let webcamAtOrigin = croppedWebcam.transformed(
                    by: CGAffineTransform(translationX: -croppedWebcam.extent.origin.x, y: -croppedWebcam.extent.origin.y)
                )

                // Apply mask to webcam
                let maskedImage = webcamAtOrigin
                    .applyingFilter("CIBlendWithAlphaMask", parameters: [
                        "inputMaskImage": mask
                    ])

                // Add shadow (optimized for performance)
                let shadowRadius = 15.0 * captureScaleFactor  // Reduced from 30
                let shadowOffset = CGSize(width: 0, height: -10 * captureScaleFactor)
                let shadowOpacity: CGFloat = 0.6

                let shadowMask = CIImage(color: CIColor.black).cropped(to: maskRect)
                    .applyingFilter("CIBlendWithAlphaMask", parameters: ["inputMaskImage": mask])

                let shadow = shadowMask
                    .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": shadowRadius])
                    .transformed(by: CGAffineTransform(translationX: shadowOffset.width, y: shadowOffset.height))
                    .applyingFilter("CIColorMatrix", parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: shadowOpacity)
                    ])

                maskedWebcam = maskedImage.composited(over: shadow)
            }

        case .squircle:
            // Squircle uses rounded rectangle with continuous corner style (same as preview)
            let maskRect = CGRect(origin: .zero, size: targetSize)
            // Use same formula as SwiftUI preview: size * 0.22 for corner radius
            let cornerRadius: CGFloat = targetSize.width * 0.22

            // Check if we can reuse cached mask
            let mask: CIImage?
            if let cachedMask = cachedMask,
               cachedMaskSize == targetSize,
               cachedMaskShape == .squircle {
                mask = cachedMask
            } else {
                // Create new mask and cache it
                mask = createSwiftUISquircleMask(size: targetSize, cornerRadius: cornerRadius)
                cachedMask = mask
                cachedMaskSize = targetSize
                cachedMaskShape = .squircle
            }

            if let mask = mask {
                if frameCount <= 3 {
                    print("  - Squircle mask created: extent=\(mask.extent)")
                }

                // Ensure webcam is cropped and positioned at origin
                let croppedWebcam = scaledWebcam.cropped(to: maskRect)
                let webcamAtOrigin = croppedWebcam.transformed(
                    by: CGAffineTransform(translationX: -croppedWebcam.extent.origin.x, y: -croppedWebcam.extent.origin.y)
                )

                // Apply mask to webcam
                let maskedImage = webcamAtOrigin
                    .applyingFilter("CIBlendWithAlphaMask", parameters: [
                        "inputMaskImage": mask
                    ])

                // Add shadow (optimized for performance)
                let shadowRadius = 15.0 * captureScaleFactor  // Reduced from 30
                let shadowOffset = CGSize(width: 0, height: -10 * captureScaleFactor)
                let shadowOpacity: CGFloat = 0.6

                let shadowMask = CIImage(color: CIColor.black).cropped(to: maskRect)
                    .applyingFilter("CIBlendWithAlphaMask", parameters: ["inputMaskImage": mask])

                let shadow = shadowMask
                    .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": shadowRadius])
                    .transformed(by: CGAffineTransform(translationX: shadowOffset.width, y: shadowOffset.height))
                    .applyingFilter("CIColorMatrix", parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: shadowOpacity)
                    ])

                maskedWebcam = maskedImage.composited(over: shadow)
            }
        }

        // Position the webcam overlay on canvas
        // IMPORTANT: Core Image uses bottom-left origin, so we need to flip Y
        // Convert from top-left (SwiftUI/UIKit) to bottom-left (Core Image)
        let flippedY = canvasSize.height - position.y - size

        if frameCount <= 3 {
            print("  - Position (top-left coords): \(position)")
            print("  - Position (Core Image coords): x=\(position.x), y=\(flippedY)")
        }

        let positioned = maskedWebcam.transformed(
            by: CGAffineTransform(translationX: position.x, y: flippedY)
        )

        return positioned
    }

    /// Helper function to create a squircle mask using SwiftUI rendering
    /// This ensures the recording matches the preview exactly
    private func createSwiftUISquircleMask(size: CGSize, cornerRadius: CGFloat) -> CIImage? {
        // Create SwiftUI view with the exact same shape as preview
        let maskView = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white)
            .frame(width: size.width, height: size.height)
            .background(Color.clear)

        // Render SwiftUI view to NSImage
        let renderer = ImageRenderer(content: maskView)
        renderer.scale = 1.0

        guard let nsImage = renderer.nsImage,
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return CIImage(cgImage: cgImage)
    }

    /// Helper function to create a rounded rectangle mask using Core Graphics
    private func createRoundedRectangleMask(size: CGSize, cornerRadius: CGFloat, continuous: Bool = false) -> CIImage? {
        let rect = CGRect(origin: .zero, size: size)

        // Create an RGBA bitmap context for proper alpha mask
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = Int(size.width) * 4

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Clear to transparent (RGBA: 0,0,0,0)
        context.clear(rect)

        // Draw white rounded rectangle with full alpha (RGBA: 1,1,1,1)
        context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

        if continuous {
            // Create squircle path using superellipse formula (continuous curve)
            let path = createSquirclePath(in: rect, cornerRadius: cornerRadius)
            context.addPath(path)
        } else {
            // Standard rounded rectangle
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.addPath(path)
        }

        context.fillPath()

        // Convert to CIImage
        if let cgImage = context.makeImage() {
            return CIImage(cgImage: cgImage)
        }

        return nil
    }

    /// Create a squircle path using superellipse formula (like SwiftUI's continuous corner style)
    private func createSquirclePath(in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let width = rect.width
        let height = rect.height
        let radius = min(cornerRadius, min(width, height) / 2)

        // Superellipse exponent (n=5 gives iOS-like squircle)
        let n: CGFloat = 5.0

        // Number of points for smooth curve
        let segments = 100

        // Start from top-left corner, going clockwise
        var isFirst = true

        // Top edge (with top-left and top-right squircle corners)
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = radius + t * (width - 2 * radius)
            let y: CGFloat

            if x < radius {
                // Top-left corner (squircle)
                let angle = .pi / 2 * (1 - x / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                y = radius - offset
            } else if x > width - radius {
                // Top-right corner (squircle)
                let angle = .pi / 2 * ((x - (width - radius)) / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                y = radius - offset
            } else {
                // Straight top edge
                y = 0
            }

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Right edge (with top-right and bottom-right squircle corners)
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let y = radius + t * (height - 2 * radius)
            let x: CGFloat

            if y < radius {
                // Top-right corner
                let angle = .pi / 2 * (y / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                x = width - radius + offset
            } else if y > height - radius {
                // Bottom-right corner
                let angle = .pi / 2 * (1 - (y - (height - radius)) / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                x = width - radius + offset
            } else {
                // Straight right edge
                x = width
            }

            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Bottom edge (with bottom-right and bottom-left squircle corners)
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = width - radius - t * (width - 2 * radius)
            let y: CGFloat

            if x > width - radius {
                // Bottom-right corner
                let angle = .pi / 2 * ((width - x) / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                y = height - radius + offset
            } else if x < radius {
                // Bottom-left corner
                let angle = .pi / 2 * (1 - x / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                y = height - radius + offset
            } else {
                // Straight bottom edge
                y = height
            }

            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Left edge (with bottom-left and top-left squircle corners)
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let y = height - radius - t * (height - 2 * radius)
            let x: CGFloat

            if y > height - radius {
                // Bottom-left corner
                let angle = .pi / 2 * ((height - y) / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                x = radius - offset
            } else if y < radius {
                // Top-left corner
                let angle = .pi / 2 * (y / radius)
                let offset = radius * pow(pow(cos(angle), n) + pow(sin(angle), n), -1/n)
                x = radius - offset
            } else {
                // Straight left edge
                x = 0
            }

            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
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
