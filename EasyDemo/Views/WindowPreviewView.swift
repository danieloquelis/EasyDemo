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
    @Binding var webcamConfig: WebcamConfiguration
    let windowScale: Double  // 0.2 to 1.0 (20% to 100%)
    @StateObject private var preview = WindowPreview()
    @StateObject private var webcam = WebcamCapture()
    @StateObject private var recordingEngine = RecordingEngine.shared
    @State private var customDragStartTopLeft: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer - contained and clipped
                backgroundView
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Window preview layer - centered by default ZStack alignment
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
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Capturing preview...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                // Webcam overlay - positioned absolutely relative to entire viewport (like recording engine)
                if webcamConfig.isEnabled {
                    webcamOverlay(in: geometry.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .task {
            await preview.capturePreview(window: window)
            await syncWebcamCapture()
        }
        .onChange(of: webcamConfig.isEnabled) { _, isEnabled in
            if isEnabled == false {
                webcam.stopCapture()
            } else if isEnabled == true {
                // Start webcam when enabled
                Task {
                    await syncWebcamCapture()
                }
            }
        }
        .onChange(of: webcamConfig.selectedDeviceId) { _, _ in
            Task {
                await syncWebcamCapture(forceRestart: true)
            }
        }
        .onChange(of: recordingEngine.isRecording) { _, isRecording in
            if isRecording {
                webcam.stopCapture()
            } else {
                Task {
                    await syncWebcamCapture()
                }
            }
        }
        .onDisappear {
            webcam.stopCapture()
        }
    }

    private func syncWebcamCapture(forceRestart: Bool = false) async {
        guard !recordingEngine.isRecording, webcamConfig.isEnabled else {
            webcam.stopCapture()
            return
        }

        do {
            if forceRestart && webcam.isCapturing {
                try await webcam.switchToDevice(deviceId: webcamConfig.selectedDeviceId)
            } else {
                try await webcam.startCapture(deviceId: webcamConfig.selectedDeviceId)
            }
        } catch {
            webcam.stopCapture()
            print("Failed to start webcam preview: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func webcamOverlay(in viewportSize: CGSize) -> some View {
        let webcamPosition = calculateWebcamPositionAbsolute(
            viewportSize: viewportSize,
            webcamSize: webcamConfig.size,
            padding: UIConstants.Padding.large
        )

        if webcam.isCapturing, let webcamFrame = webcam.currentFrame {
            let overlay = WebcamOverlayView(
                frame: webcamFrame,
                shape: webcamConfig.shape,
                size: webcamConfig.size
            )
            .position(x: webcamPosition.x, y: webcamPosition.y)

            if webcamConfig.position == .custom {
                overlay.gesture(
                    customDragGesture(
                        viewportSize: viewportSize,
                        webcamSize: webcamConfig.size,
                        padding: UIConstants.Padding.large
                    )
                )
            } else {
                overlay
            }
        } else {
            let placeholder = Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: webcamConfig.size, height: webcamConfig.size)
                .overlay(
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                )
                .position(x: webcamPosition.x, y: webcamPosition.y)

            if webcamConfig.position == .custom {
                placeholder.gesture(
                    customDragGesture(
                        viewportSize: viewportSize,
                        webcamSize: webcamConfig.size,
                        padding: UIConstants.Padding.large
                    )
                )
            } else {
                placeholder
            }
        }
    }

    /// Calculate appropriate preview size to maintain quality while showing background
    private func calculatePreviewSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let scale = calculatePreviewScale(imageSize: imageSize, containerSize: containerSize)
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    /// Calculate the scale factor used for preview (used by both window and webcam)
    private func calculatePreviewScale(imageSize: CGSize, containerSize: CGSize) -> CGFloat {
        let minMargin: CGFloat = 80  // Minimum margin to always show background
        let availableWidth = containerSize.width - (minMargin * 2)
        let availableHeight = containerSize.height - (minMargin * 2)

        // Calculate scale to fit within available space
        let widthScale = availableWidth / imageSize.width
        let heightScale = availableHeight / imageSize.height
        let fitScale = min(widthScale, heightScale, 1.0)  // Never scale up beyond original size

        // Apply user-defined window scale (0.2 to 1.0)
        return fitScale * windowScale
    }

    /// Calculate webcam overlay absolute position based on configuration
    /// Returns center position for use with .position() modifier
    /// Positions relative to the entire viewport (matching RecordingEngine behavior)
    private func calculateWebcamPositionAbsolute(
        viewportSize: CGSize,
        webcamSize: CGFloat,
        padding: CGFloat
    ) -> CGPoint {
        webcamCenterPosition(
            config: webcamConfig,
            viewportSize: viewportSize,
            webcamSize: webcamSize,
            padding: padding
        )
    }

    private func customDragGesture(
        viewportSize: CGSize,
        webcamSize: CGFloat,
        padding: CGFloat
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dragStart = customDragStartTopLeft ?? webcamTopLeftPosition(
                    config: webcamConfig,
                    viewportSize: viewportSize,
                    webcamSize: webcamSize,
                    padding: padding
                )
                if customDragStartTopLeft == nil {
                    customDragStartTopLeft = dragStart
                }

                let candidate = CGPoint(
                    x: dragStart.x + value.translation.width,
                    y: dragStart.y + value.translation.height
                )
                webcamConfig.customPosition = normalizedWebcamPosition(
                    from: candidate,
                    viewportSize: viewportSize,
                    webcamSize: webcamSize,
                    padding: padding
                )
            }
            .onEnded { _ in
                customDragStartTopLeft = nil
            }
    }

    @ViewBuilder
    private var backgroundView: some View {
        GeometryReader { geo in
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

                case .image(let url):
                    BackgroundImageView(url: url)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

/// Preview for display captures with background and scale
struct DisplayPreviewView: View {
    let display: DisplayInfo
    let backgroundStyle: BackgroundStyle
    @Binding var webcamConfig: WebcamConfiguration
    let displayScale: Double
    @StateObject private var preview = WindowPreview()
    @StateObject private var webcam = WebcamCapture()
    @StateObject private var recordingEngine = RecordingEngine.shared
    @State private var customDragStartTopLeft: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer
                backgroundView
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Display preview layer
                if let image = preview.previewImage {
                    let imageSize = CGSize(width: image.width, height: image.height)
                    let scaledSize = calculatePreviewSize(
                        imageSize: imageSize,
                        containerSize: geometry.size
                    )

                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .frame(width: scaledSize.width, height: scaledSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(
                            color: .black.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Capturing display preview...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                // Webcam overlay
                if webcamConfig.isEnabled {
                    webcamOverlay(in: geometry.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .task {
            await preview.capturePreview(display: display)
            await syncWebcamCapture()
        }
        .onChange(of: webcamConfig.isEnabled) { _, isEnabled in
            if isEnabled == false {
                webcam.stopCapture()
            } else if isEnabled == true {
                Task {
                    await syncWebcamCapture()
                }
            }
        }
        .onChange(of: webcamConfig.selectedDeviceId) { _, _ in
            Task {
                await syncWebcamCapture(forceRestart: true)
            }
        }
        .onChange(of: recordingEngine.isRecording) { _, isRecording in
            if isRecording {
                webcam.stopCapture()
            } else {
                Task {
                    await syncWebcamCapture()
                }
            }
        }
        .onDisappear {
            webcam.stopCapture()
        }
    }

    private func syncWebcamCapture(forceRestart: Bool = false) async {
        guard !recordingEngine.isRecording, webcamConfig.isEnabled else {
            webcam.stopCapture()
            return
        }

        do {
            if forceRestart && webcam.isCapturing {
                try await webcam.switchToDevice(deviceId: webcamConfig.selectedDeviceId)
            } else {
                try await webcam.startCapture(deviceId: webcamConfig.selectedDeviceId)
            }
        } catch {
            webcam.stopCapture()
            print("Failed to start webcam preview: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func webcamOverlay(in viewportSize: CGSize) -> some View {
        let webcamPosition = calculateWebcamPosition(
            viewportSize: viewportSize,
            webcamSize: webcamConfig.size,
            padding: UIConstants.Padding.large
        )

        if webcam.isCapturing, let webcamFrame = webcam.currentFrame {
            let overlay = WebcamOverlayView(
                frame: webcamFrame,
                shape: webcamConfig.shape,
                size: webcamConfig.size
            )
            .position(x: webcamPosition.x, y: webcamPosition.y)

            if webcamConfig.position == .custom {
                overlay.gesture(
                    customDragGesture(
                        viewportSize: viewportSize,
                        webcamSize: webcamConfig.size,
                        padding: UIConstants.Padding.large
                    )
                )
            } else {
                overlay
            }
        } else {
            let placeholder = Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: webcamConfig.size, height: webcamConfig.size)
                .overlay(
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                )
                .position(x: webcamPosition.x, y: webcamPosition.y)

            if webcamConfig.position == .custom {
                placeholder.gesture(
                    customDragGesture(
                        viewportSize: viewportSize,
                        webcamSize: webcamConfig.size,
                        padding: UIConstants.Padding.large
                    )
                )
            } else {
                placeholder
            }
        }
    }

    private func calculatePreviewSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let minMargin: CGFloat = 80
        let availableWidth = containerSize.width - (minMargin * 2)
        let availableHeight = containerSize.height - (minMargin * 2)

        let widthScale = availableWidth / imageSize.width
        let heightScale = availableHeight / imageSize.height
        let fitScale = min(widthScale, heightScale, 1.0)

        let scale = fitScale * displayScale
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func calculateWebcamPosition(
        viewportSize: CGSize,
        webcamSize: CGFloat,
        padding: CGFloat
    ) -> CGPoint {
        webcamCenterPosition(
            config: webcamConfig,
            viewportSize: viewportSize,
            webcamSize: webcamSize,
            padding: padding
        )
    }

    private func customDragGesture(
        viewportSize: CGSize,
        webcamSize: CGFloat,
        padding: CGFloat
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dragStart = customDragStartTopLeft ?? webcamTopLeftPosition(
                    config: webcamConfig,
                    viewportSize: viewportSize,
                    webcamSize: webcamSize,
                    padding: padding
                )
                if customDragStartTopLeft == nil {
                    customDragStartTopLeft = dragStart
                }

                let candidate = CGPoint(
                    x: dragStart.x + value.translation.width,
                    y: dragStart.y + value.translation.height
                )
                webcamConfig.customPosition = normalizedWebcamPosition(
                    from: candidate,
                    viewportSize: viewportSize,
                    webcamSize: webcamSize,
                    padding: padding
                )
            }
            .onEnded { _ in
                customDragStartTopLeft = nil
            }
    }

    @ViewBuilder
    private var backgroundView: some View {
        GeometryReader { geo in
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

                case .image(let url):
                    BackgroundImageView(url: url)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

/// Webcam overlay view for preview
struct WebcamOverlayView: View {
    let frame: CIImage
    let shape: WebcamConfiguration.Shape
    let size: CGFloat

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
                    .shadow(color: .black.opacity(0.7), radius: 15, x: 0, y: 8)

            case .roundedRectangle:
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.7), radius: 15, x: 0, y: 8)

            case .squircle:
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                    .shadow(color: .black.opacity(0.7), radius: 15, x: 0, y: 8)
            }
        }
    }
}

private func webcamTopLeftPosition(
    config: WebcamConfiguration,
    viewportSize: CGSize,
    webcamSize: CGFloat,
    padding: CGFloat
) -> CGPoint {
    config.position.offset(
        in: viewportSize,
        webcamSize: webcamSize,
        padding: padding,
        customPosition: config.customPosition
    )
}

private func webcamCenterPosition(
    config: WebcamConfiguration,
    viewportSize: CGSize,
    webcamSize: CGFloat,
    padding: CGFloat
) -> CGPoint {
    let topLeft = webcamTopLeftPosition(
        config: config,
        viewportSize: viewportSize,
        webcamSize: webcamSize,
        padding: padding
    )

    return CGPoint(
        x: topLeft.x + webcamSize / 2,
        y: topLeft.y + webcamSize / 2
    )
}

private func normalizedWebcamPosition(
    from topLeft: CGPoint,
    viewportSize: CGSize,
    webcamSize: CGFloat,
    padding: CGFloat
) -> WebcamConfiguration.NormalizedPosition {
    let minX = padding
    let minY = padding
    let maxX = max(viewportSize.width - webcamSize - padding, minX)
    let maxY = max(viewportSize.height - webcamSize - padding, minY)

    let clampedX = min(max(topLeft.x, minX), maxX)
    let clampedY = min(max(topLeft.y, minY), maxY)

    let horizontalRange = max(maxX - minX, 0)
    let verticalRange = max(maxY - minY, 0)

    let normalizedX = horizontalRange > 0 ? (clampedX - minX) / horizontalRange : 0
    let normalizedY = verticalRange > 0 ? (clampedY - minY) / verticalRange : 0

    return .init(x: normalizedX, y: normalizedY)
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
        webcamConfig: .constant(.default),
        windowScale: 1.0
    )
}

/// Helper view to load background images with security-scoped resource handling
struct BackgroundImageView: View {
    let url: URL
    @State private var loadedImage: CGImage?

    var body: some View {
        Group {
            if let cgImage = loadedImage {
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray)
            }
        }
        .task {
            loadImage()
        }
    }

    private func loadImage() {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let nsImage = NSImage(contentsOf: url),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            loadedImage = cgImage
        }
    }
}
