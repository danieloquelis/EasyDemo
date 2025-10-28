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

        // Set up AVAssetWriter
        try setupAssetWriter(configuration: configuration)

        // Set up SCStream
        try await setupStream(configuration: configuration)

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

            // Get file size
            let fileSize: Int64
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                fileSize = size
            } else {
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

        // Determine output size
        let outputSize: CGSize
        if let resolution = configuration.resolution.dimensions {
            outputSize = resolution
        } else {
            outputSize = configuration.window.bounds.size
        }

        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.codec.avCodecType,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 20_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate
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

    private func setupStream(configuration: RecordingConfiguration) async throws {
        let content = try await SCShareableContent.current

        guard let scWindow = content.windows.first(where: {
            $0.windowID == configuration.window.id
        }) else {
            throw RecordingError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(configuration.window.bounds.width)
        streamConfig.height = Int(configuration.window.bounds.height)
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = true
        streamConfig.captureResolution = .best
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
        }
    }

    // MARK: - Frame Composition

    private func composeFrame(
        _ windowBuffer: CVPixelBuffer,
        configuration: RecordingConfiguration
    ) -> CVPixelBuffer? {
        // Create output pixel buffer
        var outputBuffer: CVPixelBuffer?
        let width = CVPixelBufferGetWidth(windowBuffer)
        let height = CVPixelBufferGetHeight(windowBuffer)

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &outputBuffer
        )

        guard let output = outputBuffer else { return nil }

        // Compose background + window
        let windowImage = CIImage(cvPixelBuffer: windowBuffer)

        // Create background image
        let backgroundImage = createBackgroundImage(
            size: CGSize(width: width, height: height),
            style: configuration.background
        )

        // Composite: background + window
        var composited = windowImage.composited(over: backgroundImage)

        // Add webcam overlay if enabled
        if configuration.webcam.isEnabled, let webcamFrame = webcamCapture?.currentFrame {
            let webcamOverlay = createWebcamOverlay(
                webcamFrame: webcamFrame,
                configuration: configuration.webcam,
                canvasSize: CGSize(width: width, height: height)
            )
            composited = webcamOverlay.composited(over: composited)
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
        let size = configuration.size
        let padding: CGFloat = 40

        // Scale webcam to desired size
        let scale = size / max(webcamFrame.extent.width, webcamFrame.extent.height)
        let scaledWebcam = webcamFrame
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))

        // Calculate position
        let position = configuration.position.offset(
            in: canvasSize,
            webcamSize: size,
            padding: padding
        )

        // Apply shape mask using CIFilter
        var maskedWebcam = scaledWebcam

        switch configuration.shape {
        case .circle:
            if let filter = CIFilter(name: "CIMaskToAlpha") {
                // Create circular mask
                let maskSize = size
                let maskRect = CGRect(origin: .zero, size: CGSize(width: maskSize, height: maskSize))

                // Generate circle mask using CIRadialGradient
                if let radialFilter = CIFilter(name: "CIRadialGradient") {
                    radialFilter.setValue(CIVector(x: maskSize/2, y: maskSize/2), forKey: "inputCenter")
                    radialFilter.setValue(maskSize/2, forKey: "inputRadius0")
                    radialFilter.setValue(maskSize/2 + 1, forKey: "inputRadius1")
                    radialFilter.setValue(CIColor.white, forKey: "inputColor0")
                    radialFilter.setValue(CIColor.clear, forKey: "inputColor1")

                    if let maskImage = radialFilter.outputImage?.cropped(to: maskRect) {
                        // Composite webcam with mask
                        maskedWebcam = scaledWebcam.applyingFilter("CIBlendWithMask", parameters: [
                            kCIInputMaskImageKey: maskImage
                        ])
                    }
                }
            }

        case .roundedRectangle, .squircle:
            // For rounded rectangles and squircles, we'll use the full frame
            // Shape clipping will be handled by SwiftUI in preview
            // For recording, we keep the full rectangular frame
            break
        }

        // Position the webcam overlay
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
