//
//  WindowAccessor.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    @ObservedObject var onboardingManager = OnboardingManager.shared

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.configureWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // This will be called when onboardingManager.hasCompletedOnboarding changes
        if let window = nsView.window {
            self.configureWindow(window)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        if !onboardingManager.hasCompletedOnboarding {
            configureOnboardingWindow(window)
        } else {
            configureMainWindow(window)
        }
    }

    private func configureOnboardingWindow(_ window: NSWindow) {
        // Fixed size window (defined in UIConstants)
        let windowSize = NSSize(width: UIConstants.Onboarding.windowWidth, height: UIConstants.Onboarding.windowHeight)
        window.setContentSize(windowSize)
        window.styleMask.remove(.resizable)
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        // Center on screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - windowSize.width) / 2
            let y = screenRect.origin.y + (screenRect.height - windowSize.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        // Transparent title bar
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
    }

    private func configureMainWindow(_ window: NSWindow) {
        // First, update window styles immediately
        window.styleMask.insert(.resizable)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        // Restore normal title bar appearance
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.styleMask.remove(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true

        // Set minimum size for main window
        window.minSize = NSSize(width: UIConstants.Window.minWidth, height: UIConstants.Window.minHeight)

        // Get screen dimensions and resize to maximum available size
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame

            // Use maximum available screen size (100%) for main window
            let width = screenRect.width * UIConstants.Window.screenSizeMultiplier
            let height = screenRect.height * UIConstants.Window.screenSizeMultiplier

            // Ensure we don't go below minimum size
            let finalWidth = max(width, UIConstants.Window.minWidth)
            let finalHeight = max(height, UIConstants.Window.minHeight)

            let newSize = NSSize(width: finalWidth, height: finalHeight)

            // Position the window to fill the visible frame
            window.setFrame(
                NSRect(origin: screenRect.origin, size: newSize),
                display: true,
                animate: true
            )
        }
    }
}
