//
//  AboutWindowController.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import SwiftUI
import AppKit

final class AboutWindowController {
    static let shared = AboutWindowController()

    private var aboutWindow: NSWindow?
    private let windowSize = NSSize(width: 500, height: 520)

    private init() {}

    func showAboutWindow() {
        // If window already exists, bring it to front
        if let existingWindow = aboutWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create and configure the window
        let window = createAboutWindow()
        centerWindow(window)

        aboutWindow = window

        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createAboutWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: AboutView())

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear

        return window
    }

    private func centerWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }

        let screenRect = screen.visibleFrame
        let centerX = screenRect.origin.x + (screenRect.width - windowSize.width) / 2
        let centerY = screenRect.origin.y + (screenRect.height - windowSize.height) / 2

        window.setFrame(
            NSRect(x: centerX, y: centerY, width: windowSize.width, height: windowSize.height),
            display: true
        )
    }
}
