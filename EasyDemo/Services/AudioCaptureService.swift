//
//  AudioCaptureService.swift
//  EasyDemo
//
//  Created by Daniel Oquelis

import Foundation
import AVFoundation
import CoreAudio
import Combine

/// Service responsible for capturing audio from microphone
@MainActor
class AudioCaptureService: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var hasPermission = false

    private var microphoneEngine: AVAudioEngine?
    private var microphoneNode: AVAudioInputNode?
    private var microphoneBuffer: AVAudioPCMBuffer?
    private var selectedMicrophoneDevice: AVCaptureDevice?

    private var configuration: AudioConfiguration?

    // Audio callback
    private var microphoneCallback: ((CMSampleBuffer) -> Void)?

    // Timing
    private var audioStartTime: CMTime?
    private var firstAudioSampleTime: CMTime?

    // MARK: - Device Management

    /// Get list of available audio input devices
    func getAvailableMicrophones() -> [AVCaptureDevice] {
        if #available(macOS 14.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .external],
                mediaType: .audio,
                position: .unspecified
            )
            return discoverySession.devices
        } else {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInMicrophone, .externalUnknown],
                mediaType: .audio,
                position: .unspecified
            )
            return discoverySession.devices
        }
    }

    /// Set the microphone device to use
    func setMicrophoneDevice(_ device: AVCaptureDevice?) {
        selectedMicrophoneDevice = device
    }

    override init() {
        super.init()
    }

    // MARK: - Permission Handling

    /// Check microphone permission status
    func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        hasPermission = status == .authorized
        return hasPermission
    }

    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Capture Control

    /// Start capturing audio based on configuration
    func startCapture(
        configuration: AudioConfiguration,
        sessionStartTime: CMTime? = nil,
        callback: @escaping (CMSampleBuffer) -> Void
    ) async throws {
        guard !isCapturing else { return }
        self.configuration = configuration
        self.microphoneCallback = callback

        // Use provided session start time or create new one
        if let sessionStartTime = sessionStartTime {
            self.audioStartTime = sessionStartTime
        } else {
            self.audioStartTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
        }
        self.firstAudioSampleTime = nil

        if configuration.microphoneEnabled {
            if !checkMicrophonePermission() {
                let granted = await requestMicrophonePermission()
                if !granted {
                    throw AudioCaptureError.microphonePermissionDenied
                }
            }

            // Find the selected device if specified
            if let deviceID = configuration.selectedMicrophoneDeviceID {
                let devices = getAvailableMicrophones()
                selectedMicrophoneDevice = devices.first { $0.uniqueID == deviceID }
            }

            try startMicrophoneCapture(volume: configuration.microphoneVolume, quality: configuration.quality)
        }

        isCapturing = configuration.microphoneEnabled
    }

    /// Stop capturing audio
    func stopCapture() {
        stopMicrophoneCapture()
        isCapturing = false
        microphoneCallback = nil
        audioStartTime = nil
        firstAudioSampleTime = nil
    }

    // MARK: - Microphone Capture

    private func startMicrophoneCapture(volume: Float, quality: AudioConfiguration.AudioQuality) throws {
        // Set the audio device BEFORE creating audio engine if a specific device is selected
        if let selectedDevice = selectedMicrophoneDevice {
            var deviceID = selectedDevice.uniqueID as CFString
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            // Try to set the device (may fail due to permissions)
            _ = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                UInt32(MemoryLayout<CFString>.size),
                &deviceID
            )
        }

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode

        // Use the input node's native format instead of creating a custom one
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Check if format is valid
        guard inputFormat.channelCount > 0 && inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.invalidAudioFormat
        }

        // Install tap with native format to avoid format mismatch
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }

            // Apply volume adjustment
            self.applyVolume(to: buffer, volume: volume)

            // Convert to CMSampleBuffer and send to microphone callback
            if let sampleBuffer = self.createSampleBuffer(from: buffer, time: time) {
                Task { @MainActor in
                    self.microphoneCallback?(sampleBuffer)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        self.microphoneEngine = audioEngine
        self.microphoneNode = inputNode
    }

    private func stopMicrophoneCapture() {
        microphoneNode?.removeTap(onBus: 0)
        microphoneEngine?.stop()
        microphoneEngine = nil
        microphoneNode = nil
    }


    // MARK: - Audio Processing

    private func applyVolume(to buffer: AVAudioPCMBuffer, volume: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                samples[frame] *= volume
            }
        }
    }

    private func createSampleBuffer(from buffer: AVAudioPCMBuffer, time: AVAudioTime) -> CMSampleBuffer? {
        // Calculate presentation timestamp
        // Use CACurrentMediaTime for consistency with video stream
        let currentTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
        let presentationTime: CMTime

        if let audioStart = audioStartTime {
            // Calculate time since recording started
            let elapsedTime = CMTimeSubtract(currentTime, audioStart)

            // For the very first audio sample, ensure it starts at zero to match video
            if firstAudioSampleTime == nil {
                firstAudioSampleTime = currentTime
                presentationTime = .zero
            } else {
                presentationTime = elapsedTime
            }
        } else {
            presentationTime = .zero
        }

        // Calculate duration based on sample rate and frame count
        let sampleRate = buffer.format.sampleRate
        let frameDuration = CMTime(value: CMTimeValue(buffer.frameLength), timescale: CMTimeScale(sampleRate))

        // Create timing info
        var timingInfo = CMSampleTimingInfo(
            duration: frameDuration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        // Create format description with channel layout
        // Use a standard LPCM format that AVAssetWriter can encode
        let channelCount = UInt32(buffer.format.channelCount)
        var asbd = AudioStreamBasicDescription(
            mSampleRate: buffer.format.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,  // 4 bytes per sample per channel
            mFramesPerPacket: 1,  // 1 frame per packet
            mBytesPerFrame: 4,    // 4 bytes per frame per channel
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        // Create audio channel layout for stereo
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = channelCount == 2 ? kAudioChannelLayoutTag_Stereo : kAudioChannelLayoutTag_Mono
        channelLayout.mChannelBitmap = AudioChannelBitmap()
        channelLayout.mNumberChannelDescriptions = 0

        var format: CMFormatDescription?
        var status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: MemoryLayout<AudioChannelLayout>.size,
            layout: &channelLayout,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        )

        guard status == noErr, let format = format else {
            return nil
        }

        // Create a CMBlockBuffer from the audio data
        var blockBuffer: CMBlockBuffer?
        let audioBufferListPtr = buffer.mutableAudioBufferList

        // Calculate total buffer size
        var totalSize = 0
        for i in 0..<Int(audioBufferListPtr.pointee.mNumberBuffers) {
            let audioBuffer = UnsafeMutableBufferPointer(
                start: &audioBufferListPtr.pointee.mBuffers,
                count: Int(audioBufferListPtr.pointee.mNumberBuffers)
            )[i]
            totalSize += Int(audioBuffer.mDataByteSize)
        }

        status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: totalSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: totalSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let blockBuffer = blockBuffer else {
            return nil
        }

        // Copy audio data into the block buffer
        var offset = 0
        for i in 0..<Int(audioBufferListPtr.pointee.mNumberBuffers) {
            let audioBuffer = UnsafeMutableBufferPointer(
                start: &audioBufferListPtr.pointee.mBuffers,
                count: Int(audioBufferListPtr.pointee.mNumberBuffers)
            )[i]
            if let data = audioBuffer.mData {
                status = CMBlockBufferReplaceDataBytes(
                    with: data,
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: offset,
                    dataLength: Int(audioBuffer.mDataByteSize)
                )
                if status != noErr {
                    return nil
                }
                offset += Int(audioBuffer.mDataByteSize)
            }
        }

        // Create sample buffer with the block buffer
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sampleBuffer = sampleBuffer else {
            return nil
        }

        return sampleBuffer
    }

    // MARK: - Error Types

    enum AudioCaptureError: LocalizedError {
        case microphonePermissionDenied
        case invalidAudioFormat
        case captureStartFailed

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone permission was denied. Please grant access in System Settings."
            case .invalidAudioFormat:
                return "Failed to create audio format for capture."
            case .captureStartFailed:
                return "Failed to start audio capture."
            }
        }
    }
}


// MARK: - Helper Extensions

extension CMSampleBuffer {
    var audioBufferList: AudioBufferList? {
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        return status == noErr ? audioBufferList : nil
    }
}
