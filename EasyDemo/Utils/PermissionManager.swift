//
//  PermissionManager.swift
//  EasyDemo
//
//  Created by Claude Code on 02.11.25.
//

import Foundation
import Combine
import AVFoundation
import ScreenCaptureKit
import AppKit

/// Centralized permission management for all app permissions
@MainActor
class PermissionManager: ObservableObject {
    // MARK: - Singleton

    static let shared = PermissionManager()

    // MARK: - Published Properties

    @Published var screenRecordingStatus: PermissionStatus = .notDetermined
    @Published var cameraStatus: PermissionStatus = .notDetermined
    @Published var microphoneStatus: PermissionStatus = .notDetermined

    // MARK: - Permission Status Enum

    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
        case restricted

        var isGranted: Bool {
            return self == .authorized
        }
    }

    // MARK: - Permission Types

    enum PermissionType {
        case screenRecording
        case camera
        case microphone

        var displayName: String {
            switch self {
            case .screenRecording: return "Screen Recording"
            case .camera: return "Camera"
            case .microphone: return "Microphone"
            }
        }

        var settingsURL: String {
            switch self {
            case .screenRecording:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .camera:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
            case .microphone:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Check all permissions on initialization
        Task {
            await checkAllPermissions()
        }
    }

    // MARK: - Check All Permissions

    func checkAllPermissions() async {
        await checkScreenRecordingPermission()
        checkCameraPermission()
        checkMicrophonePermission()
    }

    // MARK: - Screen Recording Permission

    /// Check screen recording permission status WITHOUT triggering dialog
    func checkScreenRecordingPermission() async {
        // Use CGPreflightScreenCaptureAccess to check without triggering dialog
        let hasPermission = CGPreflightScreenCaptureAccess()
        screenRecordingStatus = hasPermission ? .authorized : .notDetermined
    }

    /// Request screen recording permission (triggers system dialog)
    func requestScreenRecordingPermission() async -> Bool {
        // First check current status
        await checkScreenRecordingPermission()

        if screenRecordingStatus == .authorized {
            return true
        }

        // Trigger the system dialog by requesting access
        let granted = CGRequestScreenCaptureAccess()

        // Update status after request
        await checkScreenRecordingPermission()

        return screenRecordingStatus.isGranted
    }

    // MARK: - Camera Permission

    /// Check camera permission status WITHOUT triggering dialog
    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = mapAVAuthorizationStatus(status)
    }

    /// Request camera permission (triggers system dialog if not determined)
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            cameraStatus = .authorized
            return true

        case .notDetermined:
            // This triggers the system permission dialog
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : .denied
            return granted

        case .denied, .restricted:
            cameraStatus = mapAVAuthorizationStatus(status)
            // Show alert to guide user to settings
            await showPermissionAlert(for: .camera)
            // Recheck after user potentially changed settings
            checkCameraPermission()
            return cameraStatus.isGranted

        @unknown default:
            cameraStatus = .denied
            return false
        }
    }

    // MARK: - Microphone Permission

    /// Check microphone permission status WITHOUT triggering dialog
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneStatus = mapAVAuthorizationStatus(status)
    }

    /// Request microphone permission (triggers system dialog if not determined)
    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            microphoneStatus = .authorized
            return true

        case .notDetermined:
            // This triggers the system permission dialog
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = granted ? .authorized : .denied
            return granted

        case .denied, .restricted:
            microphoneStatus = mapAVAuthorizationStatus(status)
            // Show alert to guide user to settings
            await showPermissionAlert(for: .microphone)
            // Recheck after user potentially changed settings
            checkMicrophonePermission()
            return microphoneStatus.isGranted

        @unknown default:
            microphoneStatus = .denied
            return false
        }
    }

    // MARK: - Helper Methods

    private func mapAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    private func showPermissionAlert(for type: PermissionType) async {
        let alert = NSAlert()
        alert.messageText = "\(type.displayName) Permission Required"
        alert.informativeText = """
        Please grant \(type.displayName) permission in:
        System Settings > Privacy & Security > \(type.displayName)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: type.settingsURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
