//
//  WebcamCapture.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
@preconcurrency import AVFoundation
import CoreImage
import Combine

/// Service for capturing webcam feed
@MainActor
class WebcamCapture: NSObject, ObservableObject {
    @Published var currentFrame: CIImage?
    @Published var isCapturing = false
    @Published var hasCameraPermission = false

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.easydemo.webcam", qos: .userInteractive)
    private static let preferredSessionPresets: [AVCaptureSession.Preset] = [
        .hd1920x1080,
        .hd1280x720,
        .high,
        .medium,
        .low
    ]

    // Global registry to track all active webcam instances
    private static var activeInstances: [WeakRef] = []

    private class WeakRef {
        weak var instance: WebcamCapture?
        init(_ instance: WebcamCapture) {
            self.instance = instance
        }
    }

    override init() {
        super.init()
        checkCameraPermission()
        // Register this instance
        WebcamCapture.activeInstances.append(WeakRef(self))
    }

    deinit {
        // Ensure webcam is stopped when the object is deallocated
        // Note: deinit cannot be async, so we stop the session directly
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
    }

    /// Stop all active webcam captures (called on app termination)
    static func stopAllCaptures() {
        // Clean up nil references
        activeInstances.removeAll { $0.instance == nil }

        // Stop all active instances
        for ref in activeInstances {
            if let instance = ref.instance, instance.isCapturing {
                instance.captureSession?.stopRunning()
                instance.isCapturing = false
            }
        }
    }

    /// Check camera permission status
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            hasCameraPermission = false
        case .denied, .restricted:
            hasCameraPermission = false
        @unknown default:
            hasCameraPermission = false
        }
    }

    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Start webcam capture
    func startCapture(deviceId: String? = nil) async throws {
        if !hasCameraPermission {
            let granted = await requestCameraPermission()
            if !granted {
                throw WebcamError.permissionDenied
            }
            hasCameraPermission = true
        }

        guard !isCapturing else { return }

        let session = AVCaptureSession()

        guard let device = selectDevice(withId: deviceId) else {
            throw WebcamError.noCameraAvailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = false

        session.beginConfiguration()
        do {
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                throw WebcamError.cannotAddInput
            }

            if let preset = preferredSessionPreset(for: session) {
                session.sessionPreset = preset
            }

            try configureDevice(device)

            if session.canAddOutput(output) {
                session.addOutput(output)

                if let connection = output.connection(with: .video) {
                    if connection.isVideoMirroringSupported, device.position == .front {
                        connection.isVideoMirrored = true
                    }
                    if #available(macOS 14.0, *) {
                        if connection.isVideoRotationAngleSupported(0) {
                            connection.videoRotationAngle = 0
                        }
                    } else if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            } else {
                throw WebcamError.cannotAddOutput
            }
        } catch {
            session.commitConfiguration()
            throw error
        }
        session.commitConfiguration()

        self.captureSession = session
        self.videoOutput = output

        try await startSession(session)
        isCapturing = true
    }

    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if let format = preferredFormat(for: device) {
            device.activeFormat = format
        }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
    }

    /// Stop webcam capture
    func stopCapture() {
        let session = captureSession
        captureQueue.async {
            session?.stopRunning()
        }

        captureSession = nil
        videoOutput = nil
        isCapturing = false
        currentFrame = nil
    }

    /// Restart capture switching to a new device (by uniqueID). If not capturing, does nothing unless permission is granted.
    func switchToDevice(deviceId: String?) async throws {
        let wasCapturing = isCapturing
        stopCapture()
        if wasCapturing {
            try await startCapture(deviceId: deviceId)
        }
    }

    /// List available video capture devices
    static func availableVideoDevices() -> [AVCaptureDevice] {
        discoveredVideoDevices().sorted {
            devicePriority(for: $0) > devicePriority(for: $1)
        }
    }

    /// Resolve an AVCaptureDevice based on uniqueID or return a reasonable default
    private func selectDevice(withId deviceId: String?) -> AVCaptureDevice? {
        let devices = Self.availableVideoDevices()

        if let deviceId = deviceId,
           let specified = devices.first(where: { $0.uniqueID == deviceId }) {
            return specified
        }

        return devices.first
    }

    private func startSession(_ session: AVCaptureSession) async throws {
        try await withCheckedThrowingContinuation { continuation in
            captureQueue.async {
                session.startRunning()

                if session.isRunning {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WebcamError.cannotStartSession)
                }
            }
        }
    }

    private func preferredFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let preferredDimensions = [
            CMVideoDimensions(width: 1920, height: 1080),
            CMVideoDimensions(width: 1280, height: 720)
        ]

        for target in preferredDimensions {
            if let format = device.formats.first(where: { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width == target.width && dimensions.height == target.height
            }) {
                return format
            }
        }

        return device.formats.max { lhs, rhs in
            let left = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let right = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            return (left.width * left.height) < (right.width * right.height)
        }
    }

    private func preferredSessionPreset(for session: AVCaptureSession) -> AVCaptureSession.Preset? {
        Self.preferredSessionPresets.first { session.canSetSessionPreset($0) }
    }

    private static func discoveredVideoDevices() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: supportedDeviceTypes(),
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices
    }

    private static func supportedDeviceTypes() -> [AVCaptureDevice.DeviceType] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]

        if #available(macOS 14.0, *) {
            deviceTypes.append(.continuityCamera)
            deviceTypes.append(.external)
        } else {
            deviceTypes.append(.externalUnknown)
        }

        return deviceTypes
    }

    private static func devicePriority(for device: AVCaptureDevice) -> Int {
        switch device.deviceType {
        case .builtInWideAngleCamera:
            return 300
        case .continuityCamera:
            return 200
        case .external:
            return 100
        default:
            return 0
        }
    }

    enum WebcamError: LocalizedError {
        case permissionDenied
        case noCameraAvailable
        case cannotAddInput
        case cannotAddOutput
        case cannotStartSession

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera permission denied"
            case .noCameraAvailable:
                return "No camera available"
            case .cannotAddInput:
                return "Cannot add camera input"
            case .cannotAddOutput:
                return "Cannot add video output"
            case .cannotStartSession:
                return "Camera session could not be started"
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension WebcamCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        Task { @MainActor in
            self.currentFrame = ciImage
        }
    }
}
