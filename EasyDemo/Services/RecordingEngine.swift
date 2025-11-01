import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import Combine

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
    private var captureScaleFactor: CGFloat = 2.0
    private var targetOutputSize: CGSize = .zero

    private let videoComposer = VideoComposer()
    private var webcamCapture: WebcamCapture?

    func startRecording(configuration: RecordingConfiguration) async throws {
        guard !isRecording else { return }

        self.configuration = configuration
        self.isRecording = true
        self.frameCount = 0
        self.startTime = nil
        self.recordingDuration = 0

        let content = try await SCShareableContent.current
        guard let scWindow = content.windows.first(where: { $0.windowID == configuration.window.id }) else {
            throw RecordingError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        self.captureScaleFactor = CGFloat(filter.pointPixelScale)

        try setupAssetWriter(configuration: configuration)
        try await setupStream(configuration: configuration, filter: filter)

        if configuration.webcam.isEnabled {
            let webcam = WebcamCapture()
            try await webcam.startCapture()
            self.webcamCapture = webcam
        }

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            let currentTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
            self.recordingDuration = CMTimeGetSeconds(CMTimeSubtract(currentTime, startTime))
        }
    }

    func stopRecording() async -> RecordingResult? {
        guard isRecording else { return nil }

        let finalDuration = recordingDuration
        let outputURL = configuration?.outputURL

        durationTimer?.invalidate()
        durationTimer = nil

        webcamCapture?.stopCapture()
        webcamCapture = nil

        if let stream = stream {
            try? await stream.stopCapture()
        }

        if let videoInput = videoInput {
            videoInput.markAsFinished()
        }

        if let assetWriter = assetWriter {
            await assetWriter.finishWriting()
        }

        cleanup()

        guard let url = outputURL else { return nil }

        try? await Task.sleep(nanoseconds: 500_000_000)

        let fileSize = getFileSize(at: url)

        return RecordingResult(
            fileURL: url,
            duration: finalDuration,
            fileSize: fileSize,
            timestamp: Date()
        )
    }

    private func cleanup() {
        self.stream = nil
        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil
        self.startTime = nil
        self.isRecording = false
    }

    private func getFileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    private func setupAssetWriter(configuration: RecordingConfiguration) throws {
        let writer = try AVAssetWriter(url: configuration.outputURL, fileType: .mov)

        let outputSize = calculateOutputSize(configuration: configuration)
        self.targetOutputSize = outputSize

        let videoSettings = createVideoSettings(
            outputSize: outputSize,
            frameRate: configuration.frameRate,
            codec: configuration.codec
        )

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

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

        guard writer.canAdd(videoInput) else {
            throw RecordingError.cannotAddVideoInput
        }

        writer.add(videoInput)
        self.assetWriter = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor

        writer.startWriting()
        let startTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
        writer.startSession(atSourceTime: startTime)
        self.startTime = startTime
    }

    private func calculateOutputSize(configuration: RecordingConfiguration) -> CGSize {
        if let resolution = configuration.resolution.dimensions {
            return resolution
        }

        let windowPixelWidth = configuration.window.bounds.width * captureScaleFactor
        let windowPixelHeight = configuration.window.bounds.height * captureScaleFactor
        let marginInPixels = UIConstants.Padding.minimum * 2 * captureScaleFactor

        return CGSize(
            width: windowPixelWidth + marginInPixels,
            height: windowPixelHeight + marginInPixels
        )
    }

    private func createVideoSettings(
        outputSize: CGSize,
        frameRate: Int,
        codec: RecordingConfiguration.VideoCodec
    ) -> [String: Any] {
        let pixelCount = outputSize.width * outputSize.height
        let is4K = pixelCount >= VideoConstants.Resolution.uhd4k.width * VideoConstants.Resolution.uhd4k.height * 0.9
        let bitsPerPixel: CGFloat = is4K ? VideoConstants.Bitrate.bitsPerPixel4K : VideoConstants.Bitrate.bitsPerPixelHD
        let targetBitrate = Int(pixelCount * bitsPerPixel * CGFloat(frameRate))

        return [
            AVVideoCodecKey: codec.avCodecType,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(targetBitrate, VideoConstants.Bitrate.minimum),
                AVVideoMaxKeyFrameIntervalKey: frameRate * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoQualityKey: 0.9
            ]
        ]
    }

    private func setupStream(configuration: RecordingConfiguration, filter: SCContentFilter) async throws {
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        streamConfig.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = true
        streamConfig.captureResolution = .best
        streamConfig.scalesToFit = false
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

        self.stream = stream
        try await stream.startCapture()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard let configuration = configuration,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData,
              let imageBuffer = sampleBuffer.imageBuffer else {
            return
        }

        let composedBuffer = videoComposer.composeFrame(
            windowBuffer: imageBuffer,
            configuration: configuration,
            targetOutputSize: targetOutputSize,
            scaleFactor: captureScaleFactor,
            webcamFrame: webcamCapture?.currentFrame,
            frameCount: frameCount
        )

        if let buffer = composedBuffer {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            adaptor.append(buffer, withPresentationTime: presentationTime)
            frameCount += 1
        }
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
