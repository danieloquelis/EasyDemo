//
//  WebcamCapture.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import AVFoundation
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

    override init() {
        super.init()
        checkCameraPermission()
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
    func startCapture() async throws {
        if !hasCameraPermission {
            let granted = await requestCameraPermission()
            if !granted {
                throw WebcamError.permissionDenied
            }
            hasCameraPermission = true
        }

        guard !isCapturing else { return }

        // Set up capture session
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        // Find camera device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            throw WebcamError.noCameraAvailable
        }

        // Add input
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            throw WebcamError.cannotAddInput
        }

        // Add output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            throw WebcamError.cannotAddOutput
        }

        self.captureSession = session
        self.videoOutput = output

        // Start session
        captureQueue.async {
            session.startRunning()
        }

        isCapturing = true
    }

    /// Stop webcam capture
    func stopCapture() {
        captureQueue.async {
            self.captureSession?.stopRunning()
        }

        captureSession = nil
        videoOutput = nil
        isCapturing = false
        currentFrame = nil
    }

    enum WebcamError: LocalizedError {
        case permissionDenied
        case noCameraAvailable
        case cannotAddInput
        case cannotAddOutput

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
