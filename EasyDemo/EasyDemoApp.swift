//
//  EasyDemoApp.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI
import AVFoundation

@main
struct EasyDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Constants

    private let githubURL = "https://github.com/danieloquelis/EasyDemo"

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowAccessor())
        }
        .commands {
            configureAppInfoMenu()
            configureHelpMenu()
        }
    }

    // MARK: - Menu Configuration

    private func configureAppInfoMenu() -> some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About EasyDemo") {
                AboutWindowController.shared.showAboutWindow()
            }
        }
    }

    private func configureHelpMenu() -> some Commands {
        CommandGroup(replacing: .help) {
            if let url = URL(string: githubURL) {
                Link("Documentation", destination: url)
                    .keyboardShortcut("?", modifiers: .command)

                Divider()

                Link("View Source on GitHub", destination: url)
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Stop all active webcam captures when app terminates
        // This ensures the camera indicator light turns off immediately
        Task { @MainActor in
            WebcamCapture.stopAllCaptures()
        }

        // Give the system a brief moment to release resources
        Thread.sleep(forTimeInterval: 0.15)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
