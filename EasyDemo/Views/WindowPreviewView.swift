//
//  WindowPreviewView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// View for previewing selected window with background
struct WindowPreviewView: View {
    let window: WindowInfo
    let backgroundStyle: BackgroundStyle
    let webcamConfig: WebcamConfiguration?
    @StateObject private var preview = WindowPreview()
    @StateObject private var webcam = WebcamCapture()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer - contained and clipped
                backgroundView

                // Window preview layer
                if let image = preview.previewImage {
                    let imageSize = CGSize(width: image.width, height: image.height)
                    let scaledSize = calculatePreviewSize(
                        imageSize: imageSize,
                        containerSize: geometry.size
                    )

                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .frame(width: scaledSize.width, height: scaledSize.height)
                        .shadow(
                            color: .black.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                        .overlay(alignment: .topLeading) {
                            // Webcam overlay
                            if let config = webcamConfig, config.isEnabled {
                                if webcam.isCapturing, let webcamFrame = webcam.currentFrame {
                                    let webcamPosition = calculateWebcamPosition(
                                        config: config,
                                        containerSize: geometry.size
                                    )

                                    WebcamOverlayView(
                                        frame: webcamFrame,
                                        shape: config.shape,
                                        size: config.size * 0.5,  // Scale down for preview
                                        borderWidth: config.borderWidth
                                    )
                                    .offset(x: webcamPosition.x, y: webcamPosition.y)
                                } else {
                                    // Show placeholder when webcam is enabled but not yet capturing
                                    let webcamPosition = calculateWebcamPosition(
                                        config: config,
                                        containerSize: geometry.size
                                    )

                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: config.size * 0.5, height: config.size * 0.5)
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .scaleEffect(0.6)
                                        )
                                        .offset(x: webcamPosition.x, y: webcamPosition.y)
                                }
                            }
                        }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Capturing preview...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .task {
            await preview.capturePreview(window: window)

            // Start webcam if enabled
            if let config = webcamConfig, config.isEnabled {
                try? await webcam.startCapture()
            }
        }
        .onDisappear {
            webcam.stopCapture()
        }
    }

    /// Calculate appropriate preview size to maintain quality while showing background
    private func calculatePreviewSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let minMargin: CGFloat = 80  // Minimum margin to always show background
        let availableWidth = containerSize.width - (minMargin * 2)
        let availableHeight = containerSize.height - (minMargin * 2)

        // Calculate scale to fit within available space
        let widthScale = availableWidth / imageSize.width
        let heightScale = availableHeight / imageSize.height
        let scale = min(widthScale, heightScale, 1.0)  // Never scale up beyond original size

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    /// Calculate webcam overlay offset based on configuration
    /// Returns offset from top-leading corner for use with .offset()
    private func calculateWebcamPosition(config: WebcamConfiguration, containerSize: CGSize) -> CGPoint {
        let padding: CGFloat = 40
        let size = config.size * 0.5  // Match the scaled size

        switch config.position {
        case .topLeft:
            return CGPoint(x: padding, y: padding)
        case .topRight:
            return CGPoint(x: containerSize.width - padding - size, y: padding)
        case .bottomLeft:
            return CGPoint(x: padding, y: containerSize.height - padding - size)
        case .bottomRight:
            return CGPoint(x: containerSize.width - padding - size, y: containerSize.height - padding - size)
        case .custom:
            return CGPoint(x: (containerSize.width - size) / 2, y: (containerSize.height - size) / 2)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        Group {
            switch backgroundStyle {
            case .solidColor(let color):
                Rectangle()
                    .fill(color)

            case .gradient(let colors, let startPoint, let endPoint):
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: startPoint,
                            endPoint: endPoint
                        )
                    )

            case .blur:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))

            case .image(let url):
                if let nsImage = NSImage(contentsOf: url),
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// Webcam overlay view for preview
struct WebcamOverlayView: View {
    let frame: CIImage
    let shape: WebcamConfiguration.Shape
    let size: CGFloat
    let borderWidth: CGFloat

    // Reuse CIContext for performance
    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])

    var body: some View {
        if let cgImage = Self.ciContext.createCGImage(frame, from: frame.extent) {
            switch shape {
            case .circle:
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: borderWidth))

            case .roundedRectangle:
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: borderWidth))

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
            }
        }
    }
}

#Preview {
    WindowPreviewView(
        window: WindowInfo(
            id: 1,
            ownerName: "Preview",
            windowName: "Test Window",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            alpha: 1.0,
            scWindow: nil
        ),
        backgroundStyle: .solidColor(.black),
        webcamConfig: nil
    )
}
