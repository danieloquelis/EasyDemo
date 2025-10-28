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
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
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

                // Skip windows that are not on screen (layer > 0 usually means background)
                guard window.isOnScreen else {
                    continue
                }

                // Skip minimized windows
                guard !window.frame.isEmpty else {
                    continue
                }

                // Only include windows with titles or from major apps
                let hasTitle = window.title != nil && !window.title!.isEmpty
                let isMajorApp = app.applicationName != "Window Server" &&
                                app.applicationName != "Dock" &&
                                app.applicationName != "SystemUIServer"

                guard hasTitle || isMajorApp else {
                    continue
                }

                let windowInfo = WindowInfo(
                    id: window.windowID,
                    ownerName: app.applicationName,
                    windowName: window.title,
                    bounds: window.frame,
                    layer: Int(window.windowLayer),
                    alpha: 1.0,
                    scWindow: window // Store the SCWindow for thumbnail capture
                )

                windows.append(windowInfo)
            }

            // Sort by application name and then by window title
            windows.sort { lhs, rhs in
                if lhs.ownerName == rhs.ownerName {
                    return (lhs.windowName ?? "") < (rhs.windowName ?? "")
                }
                return lhs.ownerName < rhs.ownerName
            }

            self.availableWindows = windows
        } catch {
            print("Failed to enumerate windows: \(error)")
        }
    }

    /// Capture a thumbnail of a specific window
    func captureThumbnail(for window: WindowInfo, maxSize: CGSize = CGSize(width: 200, height: 150)) async -> CGImage? {
        guard let scWindow = window.scWindow else { return nil }

        do {
            // Create a screenshot of the window
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()

            // Calculate thumbnail size maintaining aspect ratio
            let aspectRatio = window.bounds.width / window.bounds.height
            var thumbWidth: Int
            var thumbHeight: Int

            if aspectRatio > (maxSize.width / maxSize.height) {
                thumbWidth = Int(maxSize.width)
                thumbHeight = Int(maxSize.width / aspectRatio)
            } else {
                thumbHeight = Int(maxSize.height)
                thumbWidth = Int(maxSize.height * aspectRatio)
            }

            config.width = thumbWidth
            config.height = thumbHeight
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            let screenshot = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            return screenshot
        } catch {
            print("Failed to capture thumbnail: \(error)")
            return nil
        }
    }
}
