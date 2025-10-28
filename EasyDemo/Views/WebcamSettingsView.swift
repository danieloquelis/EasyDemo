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
                                print("Failed to start webcam: \(error)")
                                configuration.isEnabled = false
                            }
                        }
                    } else {
                        webcam.stopCapture()
                    }
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
                    .pickerStyle(.segmented)
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

                    Slider(value: $configuration.size, in: 100...400, step: 10)
                }

                // Border width
                VStack(alignment: .leading, spacing: 8) {
                    Text("Border Width: \(Int(configuration.borderWidth))px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Slider(value: $configuration.borderWidth, in: 0...10, step: 1)
                }

                // Preview
                if let frame = webcam.currentFrame {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        WebcamPreviewShape(
                            frame: frame,
                            shape: configuration.shape,
                            size: configuration.size / 2,
                            borderWidth: configuration.borderWidth / 2
                        )
                        .frame(height: 150)
                    }
                }
            }
        }
        .onDisappear {
            if !configuration.isEnabled {
                webcam.stopCapture()
            }
        }
    }
}

/// Preview shape for webcam
struct WebcamPreviewShape: View {
    let frame: CIImage
    let shape: WebcamConfiguration.Shape
    let size: CGFloat
    let borderWidth: CGFloat

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
                        .overlay(Circle().stroke(Color.white, lineWidth: borderWidth))
                        .frame(maxWidth: .infinity)

                case .roundedRectangle:
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: borderWidth))
                        .frame(maxWidth: .infinity)

                case .squircle:
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size / 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: size / 4, style: .continuous)
                                .stroke(Color.white, lineWidth: borderWidth)
                        )
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
