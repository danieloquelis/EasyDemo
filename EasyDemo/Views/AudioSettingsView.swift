//
//  AudioSettingsView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis

import SwiftUI
import AVFoundation

/// View for configuring audio recording settings
struct AudioSettingsView: View {
    @Binding var configuration: AudioConfiguration
    @StateObject private var audioService = AudioCaptureService()
    @State private var showPermissionAlert = false
    @State private var permissionError: String?
    @State private var availableMicrophones: [AVCaptureDevice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Microphone Section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Record Microphone", isOn: $configuration.microphoneEnabled)
                    .font(.headline)
                    .onChange(of: configuration.microphoneEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let hasPermission = await audioService.requestMicrophonePermission()
                                if !hasPermission {
                                    await MainActor.run {
                                        configuration.microphoneEnabled = false
                                        permissionError = "Microphone permission denied"
                                        showPermissionAlert = true
                                    }
                                }
                            }
                        }
                    }

                if configuration.microphoneEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        // Microphone device picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Input Device")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Picker("Microphone", selection: Binding(
                                get: { configuration.selectedMicrophoneDeviceID ?? "" },
                                set: { newValue in
                                    configuration.selectedMicrophoneDeviceID = newValue.isEmpty ? nil : newValue
                                }
                            )) {
                                Text("Default")
                                    .tag("")
                                ForEach(availableMicrophones, id: \.uniqueID) { device in
                                    Text(device.localizedName)
                                        .lineLimit(1)
                                        .tag(device.uniqueID)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Volume slider
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Volume")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(configuration.microphoneVolume * 100))%")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $configuration.microphoneVolume, in: 0.0...1.0, step: 0.05)
                        }
                    }
                    .padding(.leading, 20)
                }
            }


            if configuration.isEnabled {
                Divider()

                // Audio Quality Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Quality")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Quality", selection: $configuration.quality) {
                        ForEach(AudioConfiguration.AudioQuality.allCases) { quality in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quality.rawValue)
                                    .font(.body)
                                Text(qualityDescription(for: quality))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(qualityDetailedDescription(for: configuration.quality))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                        .padding(8)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                }

                // Pro tip
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .frame(width: 12, height: 12)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pro Tip")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(getProTip())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
        .onAppear {
            // Load available microphones
            availableMicrophones = audioService.getAvailableMicrophones()
        }
        .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant microphone permission in System Settings > Privacy & Security > Microphone to record audio.\n\nError: \(permissionError ?? "Unknown")")
        }
    }

    // MARK: - Helper Functions

    private func qualityDescription(for quality: AudioConfiguration.AudioQuality) -> String {
        switch quality {
        case .standard:
            return "Good for most recordings"
        case .high:
            return "Clear, professional quality"
        case .lossless:
            return "Maximum audio fidelity"
        }
    }

    private func qualityDetailedDescription(for quality: AudioConfiguration.AudioQuality) -> String {
        switch quality {
        case .standard:
            return "🎵 128 kbps - Good quality for voice and presentations. Smaller file sizes (~1-2 MB/min)."
        case .high:
            return "🎧 192 kbps - Professional quality for demos and tutorials. Balanced size (~2-3 MB/min)."
        case .lossless:
            return "💎 256 kbps - Studio quality for music and high-fidelity recordings. Larger files (~4-5 MB/min)."
        }
    }

    private func getProTip() -> String {
        if configuration.microphoneEnabled {
            return "Adjust microphone volume to balance your voice in the recording."
        } else {
            return "Enable microphone to include audio in your recording."
        }
    }
}

#Preview {
    AudioSettingsView(configuration: .constant(.default))
        .padding()
        .frame(width: 350)
}
