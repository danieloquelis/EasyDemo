//
//  AboutView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import SwiftUI

struct AboutView: View {
    // MARK: - Properties

    @Environment(\.colorScheme)
    private var colorScheme

    private let githubURL = "https://github.com/danieloquelis/EasyDemo"
    private let iconSize: CGFloat = 128
    private let iconCornerRadius: CGFloat = 28
    private let windowSize = CGSize(width: 500, height: 520)

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var descriptionTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 30)

                descriptionSection
                    .padding(.bottom, 30)

                buttonsSection
                    .padding(.bottom, 30)

                contributionSection
                    .padding(.bottom, 25)

                Spacer()
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 16) {
            appIconView
                .padding(.top, 40)

            Text("EasyDemo")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(primaryTextColor)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    private var appIconView: some View {
        Group {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                fallbackIconView
            }
        }
    }

    private var fallbackIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            Image(systemName: "video.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.white)
        }
    }

    private var descriptionSection: some View {
        VStack(spacing: 16) {
            Text("Copyright © 2025 Daniel Oquelis")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("A free, open-source screen recorder for macOS.")
                    .descriptionText(color: descriptionTextColor)

                Text("Professional-quality recordings shouldn't be behind a paywall.")
                    .descriptionText(color: descriptionTextColor)

                Text("For those who want a quick styled screen recording.")
                    .descriptionText(color: descriptionTextColor)
            }
            .padding(.horizontal, 40)
        }
    }

    private var buttonsSection: some View {
        HStack(spacing: 12) {
            actionButton(title: "Documentation")
            actionButton(title: "View on GitHub")
        }
    }

    private func actionButton(title: String) -> some View {
        Button(action: openGitHub) {
            Text(title)
                .font(.system(size: 13))
                .frame(width: 140)
                .padding(.vertical, 8)
        }
        .buttonStyle(AboutButtonStyle())
    }

    private var contributionSection: some View {
        VStack(spacing: 4) {
            Text("Want to contribute?")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(descriptionTextColor)

            Text("We welcome contributors!")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 50)
    }

    // MARK: - Actions

    private func openGitHub() {
        guard let url = URL(string: githubURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Button Style

struct AboutButtonStyle: ButtonStyle {
    @Environment(\.colorScheme)
    private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        colorScheme == .dark
                        ? Color.white.opacity(configuration.isPressed ? 0.15 : 0.1)
                        : Color.black.opacity(configuration.isPressed ? 0.15 : 0.08)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        colorScheme == .dark
                        ? Color.white.opacity(0.15)
                        : Color.black.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
            .foregroundColor(colorScheme == .dark ? .white : .black)
    }
}

// MARK: - View Extensions

private extension Text {
    func descriptionText(color: Color) -> some View {
        self
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .foregroundColor(color)
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}
