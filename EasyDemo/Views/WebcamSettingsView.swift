//
//  WebcamSettingsView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI
import AVFoundation

/// View for configuring webcam overlay settings
struct WebcamSettingsView: View {
    @Binding var configuration: WebcamConfiguration
    @State private var showPermissionAlert = false
    @State private var permissionError: String?
    @State private var devices: [AVCaptureDevice] = []

    private var selectedDeviceBinding: Binding<String> {
        Binding<String>(
            get: { configuration.selectedDeviceId ?? "" },
            set: { newValue in
                configuration.selectedDeviceId = newValue.isEmpty ? nil : newValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable toggle
            Toggle("Enable Webcam Overlay", isOn: $configuration.isEnabled)
                .font(.headline)
                .onChange(of: configuration.isEnabled) { _, newValue in
                    if newValue {
                        Task {
                            let granted = await PermissionManager.shared.requestCameraPermission()
                            guard granted else {
                                await MainActor.run {
                                    configuration.isEnabled = false
                                    permissionError = StringConstants.Permission.cameraMessage
                                    showPermissionAlert = true
                                }
                                return
                            }

                            await MainActor.run {
                                refreshDevices()
                                validateSelectedDevice()

                                if devices.isEmpty {
                                    configuration.isEnabled = false
                                    permissionError = WebcamCapture.WebcamError.noCameraAvailable.localizedDescription
                                    showPermissionAlert = true
                                }
                            }
                        }
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

                // Camera device selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Camera")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Camera", selection: selectedDeviceBinding) {
                        Text("System Default").tag("")
                        ForEach(devices, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .pickerStyle(.menu)
                }

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
                    .onChange(of: configuration.position) { oldValue, newValue in
                        if newValue == .custom, configuration.customPosition == nil {
                            configuration.customPosition = defaultCustomPosition(from: oldValue)
                        }
                    }

                    if configuration.position == .custom {
                        Text("Drag the webcam in the preview to place it exactly where you want.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
            refreshDevices()
            validateSelectedDevice()
        }
        // Refresh device list on connect/disconnect
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            refreshDevices()
            validateSelectedDevice()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            refreshDevices()
            validateSelectedDevice()
        }
    }

    private func refreshDevices() {
        devices = WebcamCapture.availableVideoDevices()
    }

    private func validateSelectedDevice() {
        if let selectedId = configuration.selectedDeviceId,
           !devices.contains(where: { $0.uniqueID == selectedId }) {
            configuration.selectedDeviceId = nil
        }
    }

    private func defaultCustomPosition(from previousPosition: WebcamConfiguration.Position) -> WebcamConfiguration.NormalizedPosition {
        switch previousPosition {
        case .topLeft:
            return .init(x: 0, y: 0)
        case .topRight:
            return .init(x: 1, y: 0)
        case .bottomLeft:
            return .init(x: 0, y: 1)
        case .bottomRight:
            return .init(x: 1, y: 1)
        case .custom:
            return configuration.customPosition ?? .init(x: 0, y: 0)
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
