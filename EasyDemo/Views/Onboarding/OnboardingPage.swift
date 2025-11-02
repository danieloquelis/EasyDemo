//
//  OnboardingPage.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import SwiftUI

// MARK: - Onboarding Page Protocol

protocol OnboardingPageContent {
    var pageNumber: Int { get }
}

// MARK: - Welcome Page

struct WelcomePage: View, OnboardingPageContent {
    let pageNumber = 0

    var body: some View {
        VStack(spacing: UIConstants.Onboarding.contentSpacing) {
            // App Icon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(
                        width: UIConstants.Onboarding.appIconSize,
                        height: UIConstants.Onboarding.appIconSize
                    )
                    .clipShape(RoundedRectangle(
                        cornerRadius: UIConstants.Onboarding.appIconCornerRadius,
                        style: .continuous
                    ))
                    .shadow(
                        color: .black.opacity(UIConstants.Onboarding.appIconShadowOpacity),
                        radius: UIConstants.Onboarding.appIconShadowRadius,
                        x: 0,
                        y: UIConstants.Onboarding.appIconShadowY
                    )
            }

            VStack(spacing: UIConstants.Onboarding.sectionSpacing) {
                Text("Welcome to EasyDemo")
                    .font(.system(size: UIConstants.Typography.welcomeTitleSize, weight: .bold))
                    .foregroundColor(.primary)

                Text("Professional screen recordings made simple and beautiful")
                    .font(.system(size: UIConstants.Typography.welcomeSubtitleSize))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, UIConstants.Padding.large)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Feature highlights
            VStack(spacing: UIConstants.Onboarding.featureRowSpacing) {
                FeatureRow(
                    icon: "sparkles",
                    title: "Styled Recordings",
                    description: "Custom backgrounds and effects"
                )

                FeatureRow(
                    icon: "video.fill",
                    title: "Window Capture",
                    description: "Record specific windows with ease"
                )

                FeatureRow(
                    icon: "heart.fill",
                    title: "Free Forever",
                    description: "Open source and built for creators"
                )
            }
            .padding(.horizontal, UIConstants.Padding.large)
        }
        .padding(UIConstants.Padding.large)
    }
}

// MARK: - Permissions Page

struct PermissionsPage: View, OnboardingPageContent {
    let pageNumber: Int
    let icon: String
    let title: String
    let description: String

    @Binding var permissionGranted: Bool
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isRequesting = false

    init(icon: String, title: String, description: String, pageNumber: Int = 1, permissionGranted: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self.description = description
        self.pageNumber = pageNumber
        self._permissionGranted = permissionGranted
    }

    var body: some View {
        VStack(spacing: UIConstants.Padding.large) {

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                UIConstants.Colors.brandBlue.opacity(UIConstants.Colors.materialOpacity),
                                UIConstants.Colors.brandOrange.opacity(UIConstants.Colors.materialOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: UIConstants.Onboarding.permissionIconCircleSize,
                        height: UIConstants.Onboarding.permissionIconCircleSize
                    )

                Image(systemName: icon)
                    .font(.system(size: UIConstants.Onboarding.permissionIconSize))
                    .foregroundColor(UIConstants.Colors.brandBlue)
            }
            .onAppear {
                checkPermissionStatus()
            }

            VStack(spacing: UIConstants.Onboarding.sectionSpacing) {
                Text(title)
                    .font(.system(size: UIConstants.Typography.permissionsTitleSize, weight: .bold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: UIConstants.Typography.permissionsDescriptionSize))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Permission button
            Button(action: requestPermission) {
                HStack {
                    if permissionGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: UIConstants.Typography.permissionsDescriptionSize + 2))
                    }

                    Text(permissionGranted ? "Permission Granted" : "Grant Permission")
                        .font(.system(size: UIConstants.Typography.buttonTextSize, weight: .semibold))
                }
                .foregroundColor(permissionGranted ? .green : .white)
                .frame(maxWidth: UIConstants.Onboarding.permissionButtonMaxWidth)
                .padding(.vertical, UIConstants.Onboarding.buttonVerticalPadding)
                .background(
                    Group {
                        if permissionGranted {
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(UIConstants.Colors.materialOpacity),
                                    Color.green.opacity(UIConstants.Colors.materialOpacity)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: UIConstants.Colors.buttonGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(Capsule())
            }
            .disabled(permissionGranted || isRequesting)
            .buttonStyle(.plain)
        }
        .padding(UIConstants.Padding.large)
    }

    private func checkPermissionStatus() {
        Task {
            var granted = false

            switch pageNumber {
            case 1: // Screen Recording
                await permissionManager.checkScreenRecordingPermission()
                granted = permissionManager.screenRecordingStatus.isGranted
            case 2: // Camera
                permissionManager.checkCameraPermission()
                granted = permissionManager.cameraStatus.isGranted
            case 3: // Microphone
                permissionManager.checkMicrophonePermission()
                granted = permissionManager.microphoneStatus.isGranted
            default:
                break
            }

            await MainActor.run {
                withAnimation(.spring()) {
                    permissionGranted = granted
                }
            }
        }
    }

    private func requestPermission() {
        // Prevent multiple simultaneous requests
        guard !isRequesting else { return }

        Task {
            isRequesting = true
            var granted = false

            switch pageNumber {
            case 1: // Screen Recording
                granted = await permissionManager.requestScreenRecordingPermission()
            case 2: // Camera
                granted = await permissionManager.requestCameraPermission()
            case 3: // Microphone
                granted = await permissionManager.requestMicrophonePermission()
            default:
                break
            }

            await MainActor.run {
                withAnimation(.spring()) {
                    permissionGranted = granted
                    isRequesting = false
                }
            }
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: UIConstants.Onboarding.sectionSpacing) {
            Image(systemName: icon)
                .font(.system(size: UIConstants.Onboarding.featureIconSize))
                .foregroundColor(UIConstants.Colors.brandBlue)
                .frame(width: UIConstants.Onboarding.featureIconWidth)

            VStack(alignment: .leading, spacing: UIConstants.Padding.extraTight) {
                Text(title)
                    .font(.system(size: UIConstants.Typography.featureTitleSize, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: UIConstants.Typography.featureDescriptionSize))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Welcome") {
    WelcomePage()
}

#Preview("Permissions") {
    struct PreviewWrapper: View {
        @State private var granted = false

        var body: some View {
            PermissionsPage(
                icon: "video.badge.checkmark",
                title: "Screen Recording",
                description: "EasyDemo needs permission to capture your screen.",
                permissionGranted: $granted
            )
        }
    }

    return PreviewWrapper()
}
