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
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var configuration: RecordingConfiguration?
    private var startTime: CMTime?
    private var frameCount: Int64 = 0
    private var audioSampleCount: Int64 = 0
    private var durationTimer: Timer?
    private var captureScaleFactor: CGFloat = 2.0
    private var targetOutputSize: CGSize = .zero

    private let videoComposer = VideoComposer()
    private var webcamCapture: WebcamCapture?
    private var audioCapture: AudioCaptureService?

    func startRecording(configuration: RecordingConfiguration) async throws {
        guard !isRecording else { return }

        self.configuration = configuration
        self.isRecording = true
        self.frameCount = 0
        self.audioSampleCount = 0
        self.startTime = nil
        self.recordingDuration = 0

        let content = try await SCShareableContent.current
        guard let scWindow = content.windows.first(where: { $0.windowID == configuration.window.id }) else {
            throw RecordingError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        self.captureScaleFactor = CGFloat(filter.pointPixelScale)

        // Setup asset writer - this starts the recording session and sets self.startTime
        try setupAssetWriter(configuration: configuration)

        // Start microphone/audio capture if enabled
        if configuration.audio.microphoneEnabled {
            let audioService = AudioCaptureService()
            try await audioService.startCapture(
                configuration: configuration.audio,
                sessionStartTime: self.startTime
            ) { [weak self] sampleBuffer in
                guard let self = self else { return }
                self.processAudioSample(sampleBuffer)
            }
            self.audioCapture = audioService
        }

        // Start video stream
        try await setupStream(configuration: configuration, filter: filter)

        // Start webcam if enabled
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

        audioCapture?.stopCapture()
        audioCapture = nil

        if let stream = stream {
            try? await stream.stopCapture()
        }

        if let videoInput = videoInput {
            videoInput.markAsFinished()
        }

        if let audioInput = audioInput {
            audioInput.markAsFinished()
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
        self.audioInput = nil
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

        // Add audio input if enabled
        if configuration.audio.microphoneEnabled {
            let audioSettings = createAudioSettings(quality: configuration.audio.quality)
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true

            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                self.audioInput = audioInput
            }
        }

        self.assetWriter = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor

        writer.startWriting()
        // Start session at time zero - samples will have timestamps relative to this
        writer.startSession(atSourceTime: .zero)
        // Store the actual wall clock time when we started for timestamp calculations
        self.startTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
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

    private func createAudioSettings(quality: AudioConfiguration.AudioQuality) -> [String: Any] {
        // Create audio channel layout
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        channelLayout.mChannelBitmap = AudioChannelBitmap()
        channelLayout.mNumberChannelDescriptions = 0

        let channelLayoutData = Data(bytes: &channelLayout, count: MemoryLayout<AudioChannelLayout>.size)

        // Important: Match the sample rate with incoming audio (48kHz)
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000.0,  // Match input sample rate
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: channelLayoutData,
            AVEncoderBitRateKey: quality.bitrate
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
        switch type {
        case .screen:
            handleVideoSample(sampleBuffer)
        case .audio, .microphone:
            // Audio is handled by AudioCaptureService
            break
        @unknown default:
            break
        }
    }

    private func handleVideoSample(_ sampleBuffer: CMSampleBuffer) {
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
            // Convert timestamp to be relative to recording start time
            let currentTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
            let presentationTime: CMTime

            if let startTime = startTime {
                presentationTime = CMTimeSubtract(currentTime, startTime)
            } else {
                presentationTime = .zero
            }

            adaptor.append(buffer, withPresentationTime: presentationTime)
            frameCount += 1
        }
    }


    nonisolated private func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        Task { @MainActor in
            guard let audioInput = self.audioInput,
                  audioInput.isReadyForMoreMediaData else {
                return
            }

            // Append the audio sample (already has correct timestamp from AudioCaptureService)
            audioInput.append(sampleBuffer)
            self.audioSampleCount += 1
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
