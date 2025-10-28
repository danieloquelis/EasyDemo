//
//  WindowCapture.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import CoreGraphics
import AppKit
import Combine
import ScreenCaptureKit

/// Service responsible for enumerating and capturing macOS windows
@MainActor
class WindowCapture: ObservableObject {
    @Published var availableWindows: [WindowInfo] = []
    @Published var hasScreenRecordingPermission = false

    init() {
        Task {
            await checkScreenRecordingPermission()
        }
    }

    /// Check if screen recording permission is granted
    func checkScreenRecordingPermission() async {
        do {
            // Attempt to get shareable content to check permission
            _ = try await SCShareableContent.current
            hasScreenRecordingPermission = true
        } catch {
            hasScreenRecordingPermission = false
        }
    }

    /// Request screen recording permission from the user
    func requestScreenRecordingPermission() async {
        // Trigger permission dialog by attempting to get shareable content
        await checkScreenRecordingPermission()

        // If permission denied, guide user to System Settings
        if !hasScreenRecordingPermission {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = """
            Please grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Enumerate all visible windows on screen
    func enumerateWindows() async {
        guard hasScreenRecordingPermission else {
            await requestScreenRecordingPermission()
            return
        }

        do {
            let content = try await SCShareableContent.current
            var windows: [WindowInfo] = []

            for window in content.windows {
                // Skip windows from our own app
                if window.owningApplication?.applicationName == "EasyDemo" {
                    continue
                }

                // Skip windows with zero or invalid bounds
                guard window.frame.width > 100 && window.frame.height > 100 else {
                    continue
                }

                // Skip windows without an owning application
                guard let app = window.owningApplication else {
                    continue
                }

                let windowInfo = WindowInfo(
                    id: window.windowID,
                    ownerName: app.applicationName,
                    windowName: window.title,
                    bounds: window.frame,
                    layer: Int(window.windowLayer),
                    alpha: 1.0 // ScreenCaptureKit doesn't provide alpha
                )

                windows.append(windowInfo)
            }

            // Sort by layer (lower layer = more prominent)
            windows.sort { $0.layer < $1.layer }

            self.availableWindows = windows
        } catch {
            print("Failed to enumerate windows: \(error)")
        }
    }

    /// Capture an image of a specific window (placeholder for future implementation)
    func captureWindow(_ windowInfo: WindowInfo) async -> CGImage? {
        // This will be implemented in Milestone 2 using SCStream
        return nil
    }
}
