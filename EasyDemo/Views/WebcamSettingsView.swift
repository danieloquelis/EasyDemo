//
//  WebcamSettingsView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// View for configuring webcam overlay settings
struct WebcamSettingsView: View {
    @Binding var configuration: WebcamConfiguration
    @StateObject private var webcam = WebcamCapture()
    @State private var showPermissionAlert = false
    @State private var permissionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable toggle
            Toggle("Enable Webcam Overlay", isOn: $configuration.isEnabled)
                .font(.headline)
                .onChange(of: configuration.isEnabled) { _, newValue in
                    if newValue {
                        Task {
                            do {
                                try await webcam.startCapture()
                            } catch {
                                await MainActor.run {
                                    configuration.isEnabled = false
                                    permissionError = error.localizedDescription
                                    showPermissionAlert = true
                                }
                            }
                        }
                    } else {
                        webcam.stopCapture()
                    }
                }
                .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Please grant camera permission in System Settings > Privacy & Security > Camera to use webcam overlay.\n\nError: \(permissionError ?? "Unknown")")
                }

            if configuration.isEnabled {
                Divider()

                // Shape selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shape")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Shape", selection: $configuration.shape) {
                        ForEach(WebcamConfiguration.Shape.allCases) { shape in
                            Text(shape.rawValue).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Position selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Position", selection: $configuration.position) {
                        ForEach(WebcamConfiguration.Position.allCases) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Size slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Size: \(Int(configuration.size))px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Slider(value: $configuration.size, in: UIConstants.Size.webcamMin...UIConstants.Size.webcamMax, step: 10)
                        .frame(height: 20)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
        .onAppear {
            // Restart webcam capture if enabled when view appears
            if configuration.isEnabled && !webcam.isCapturing {
                Task {
                    try? await webcam.startCapture()
                }
            }
        }
        .onDisappear {
            webcam.stopCapture()
        }
    }
}

/// Preview shape for webcam (unused - kept for compatibility)
struct WebcamPreviewShape: View {
    let frame: CIImage
    let shape: WebcamConfiguration.Shape
    let size: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let ciContext = CIContext()
            if let cgImage = ciContext.createCGImage(frame, from: frame.extent) {
                switch shape {
                case .circle:
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.7), radius: 15, x: 0, y: 8)
                        .frame(maxWidth: .infinity)

                case .roundedRectangle:
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.7), radius: 15, x: 0, y: 8)
                        .frame(maxWidth: .infinity)

                case .squircle:
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                        .shadow(color: .black.opacity(0.7), radius: 15, x: 0, y: 8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    WebcamSettingsView(configuration: .constant(.default))
        .padding()
}
