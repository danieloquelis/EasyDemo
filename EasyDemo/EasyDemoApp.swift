//
//  EasyDemoApp.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

@main
struct EasyDemoApp: App {
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
