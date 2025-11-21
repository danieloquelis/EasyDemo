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
        let audioEngine = AVAudioEngine()
        
        // Set the audio device BEFORE accessing the input node if a specific device is selected
        if let selectedDevice = selectedMicrophoneDevice {
            print("🎤 Attempting to set audio device: \(selectedDevice.localizedName) (ID: \(selectedDevice.uniqueID))")
            
            // Convert the device's unique ID to an AudioDeviceID
            if let audioDeviceID = getAudioDeviceID(for: selectedDevice.uniqueID) {
                print("🎤 Found AudioDeviceID: \(audioDeviceID)")
                
                // Get the input node first to trigger Audio Unit creation
                let inputNode = audioEngine.inputNode
                
                if let audioUnit = inputNode.audioUnit {
                    // First, uninitialize the audio unit
                    AudioUnitUninitialize(audioUnit)
                    
                    // Set the device on the audio unit
                    var deviceID = audioDeviceID
                    let status = AudioUnitSetProperty(
                        audioUnit,
                        kAudioOutputUnitProperty_CurrentDevice,
                        kAudioUnitScope_Global,
                        0,
                        &deviceID,
                        UInt32(MemoryLayout<AudioDeviceID>.size)
                    )
                    
                    if status == noErr {
                        print("🎤 Successfully set audio input device to: \(selectedDevice.localizedName)")
                        
                        // Reinitialize the audio unit with the new device
                        let initStatus = AudioUnitInitialize(audioUnit)
                        if initStatus == noErr {
                            print("🎤 Audio unit reinitialized successfully")
                        } else {
                            print("❌ Failed to reinitialize audio unit. Status: \(initStatus)")
                        }
                    } else {
                        print("❌ Failed to set audio input device. Status: \(status)")
                        // Try to get a human-readable error
                        if let error = getOSStatusError(status) {
                            print("❌ Error: \(error)")
                        }
                        // Reinitialize anyway
                        AudioUnitInitialize(audioUnit)
                    }
                } else {
                    print("❌ Could not get AudioUnit from input node")
                }
            } else {
                print("❌ Could not find AudioDeviceID for device: \(selectedDevice.localizedName)")
            }
        } else {
            print("🎤 Using default audio input device")
        }

        let inputNode = audioEngine.inputNode
        
        // Use the input node's native format instead of creating a custom one
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Input format: \(inputFormat.channelCount) channels, \(inputFormat.sampleRate) Hz")

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

    /// Get human-readable error message for OSStatus
    private func getOSStatusError(_ status: OSStatus) -> String? {
        switch status {
        case kAudioUnitErr_InvalidProperty:
            return "Invalid property"
        case kAudioUnitErr_InvalidParameter:
            return "Invalid parameter"
        case kAudioUnitErr_InvalidElement:
            return "Invalid element"
        case kAudioUnitErr_NoConnection:
            return "No connection"
        case kAudioUnitErr_FailedInitialization:
            return "Failed initialization"
        case kAudioUnitErr_PropertyNotWritable:
            return "Property not writable"
        default:
            return "Unknown error code: \(status)"
        }
    }
    
    /// Convert a device's unique ID string to an AudioDeviceID
    private func getAudioDeviceID(for deviceUID: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get the number of audio devices
        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else { return nil }
        
        // Get all device IDs
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard status == noErr else { return nil }
        
        // Find the device with matching UID
        for deviceID in deviceIDs {
            var uidPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var uidCFString: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            
            status = AudioObjectGetPropertyData(
                deviceID,
                &uidPropertyAddress,
                0,
                nil,
                &uidSize,
                &uidCFString
            )
            
            if status == noErr, let uid = uidCFString as String?, uid == deviceUID {
                return deviceID
            }
        }
        
        return nil
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
