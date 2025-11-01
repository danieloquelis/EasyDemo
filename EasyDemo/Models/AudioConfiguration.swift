//
//  AudioConfiguration.swift
//  EasyDemo
//
//  Created by Daniel Oquelis

import Foundation
import AVFoundation

/// Configuration for audio capture during recording
struct AudioConfiguration: Equatable {
    /// Whether microphone audio is enabled
    var microphoneEnabled: Bool

    /// Selected microphone device ID
    var selectedMicrophoneDeviceID: String?

    /// Microphone volume (0.0 - 1.0)
    var microphoneVolume: Float

    /// Audio quality/bitrate
    var quality: AudioQuality

    static func == (lhs: AudioConfiguration, rhs: AudioConfiguration) -> Bool {
        lhs.microphoneEnabled == rhs.microphoneEnabled &&
        lhs.selectedMicrophoneDeviceID == rhs.selectedMicrophoneDeviceID &&
        lhs.microphoneVolume == rhs.microphoneVolume &&
        lhs.quality == rhs.quality
    }

    enum AudioQuality: String, CaseIterable, Identifiable {
        case standard = "Standard (128 kbps)"
        case high = "High (192 kbps)"
        case lossless = "Lossless (256 kbps)"

        var id: String { rawValue }

        var bitrate: Int {
            switch self {
            case .standard:
                return 128_000
            case .high:
                return 192_000
            case .lossless:
                return 256_000
            }
        }

        var sampleRate: Double {
            return 48_000.0
        }
    }

    /// Whether any audio is enabled
    var isEnabled: Bool {
        microphoneEnabled
    }

    static var `default`: AudioConfiguration {
        AudioConfiguration(
            microphoneEnabled: false,
            selectedMicrophoneDeviceID: nil,
            microphoneVolume: 1.0,
            quality: .high
        )
    }
}
