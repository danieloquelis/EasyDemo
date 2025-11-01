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

                // Skip windows without an owning application
                guard let app = window.owningApplication else {
                    continue
                }

                // Apply generic filters to identify recordable windows
                guard isRecordableWindow(window, app: app) else {
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

    /// Generic filter to determine if a window is recordable by the user
    /// Uses heuristics based on window properties without hardcoding app names
    private func isRecordableWindow(_ window: SCWindow, app: SCRunningApplication) -> Bool {
        // 1. Minimum size check - user windows are typically larger
        // System UI elements and background processes have small or zero sizes
        guard window.frame.width > 100 && window.frame.height > 100 else {
            return false
        }

        // 2. Window must be on screen and not minimized
        guard window.isOnScreen && !window.frame.isEmpty else {
            return false
        }

        // 3. Window must have a meaningful title
        // System windows often have no title or generic titles like "Wallpaper", "Dock", "Backstop"
        guard let title = window.title, !title.isEmpty else {
            return false
        }

        // 4. Filter out common system window patterns by title
        let systemWindowPatterns = [
            "wallpaper",
            "backstop",
            "dock",
            "item-0",
            "window"
        ]

        let titleLower = title.lowercased()
        for pattern in systemWindowPatterns {
            if titleLower.contains(pattern) {
                return false
            }
        }

        // 5. Filter out windows with display names (e.g., "Display 1")
        if titleLower.starts(with: "display") {
            return false
        }

        // 6. Filter out windows that start with special characters or are unnamed
        // These are typically system UI elements
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if trimmedTitle.isEmpty || trimmedTitle.hasPrefix("-") {
            return false
        }

        // 7. Window layer check - windows at layer 0 are typically user-facing
        // Background system windows often have higher layers
        guard window.windowLayer == 0 else {
            return false
        }

        // 8. Additional check: window should have reasonable aspect ratio
        // Extremely thin or wide windows are likely UI elements
        let aspectRatio = window.frame.width / window.frame.height
        guard aspectRatio > 0.3 && aspectRatio < 5.0 else {
            return false
        }

        // 9. Check if the app bundle identifier suggests it's a system component
        // System apps often have com.apple.* bundle IDs with specific patterns
        let bundleID = app.bundleIdentifier
        let systemBundlePatterns = [
            "com.apple.dock",
            "com.apple.systemuiserver",
            "com.apple.windowserver",
            "com.apple.screencapturekit"
        ]

        let bundleLower = bundleID.lowercased()
        for pattern in systemBundlePatterns {
            if bundleLower.contains(pattern) {
                return false
            }
        }

        return true
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
