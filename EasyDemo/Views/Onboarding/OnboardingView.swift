//
//  OnboardingView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import SwiftUI

struct OnboardingView: View {
    // MARK: - Properties

    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var currentPage = 0
    @State private var screenRecordingGranted = false
    @State private var cameraAccessGranted = false
    @State private var microphoneAccessGranted = false

    private var totalPages: Int {
        4 // Welcome + Screen Recording + Camera Access + Microphone Access
    }

    private var canProceed: Bool {
        switch currentPage {
        case 1: // Screen recording permission page
            return screenRecordingGranted
        case 2: // Camera permission page
            return cameraAccessGranted
        case 3: // Microphone permission page
            return microphoneAccessGranted
        default: // Welcome page and others
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()

            // Centered glassmorphic card with all content
            VStack(spacing: 0) {
                ZStack {
                    // Blur background
                    RoundedRectangle(cornerRadius: UIConstants.Onboarding.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(
                            color: .black.opacity(UIConstants.Onboarding.cardShadowOpacity),
                            radius: UIConstants.Onboarding.cardShadowRadius,
                            x: 0,
                            y: UIConstants.Onboarding.cardShadowY
                        )

                    // All content inside card
                    VStack {
                        // Main content area
                        Group {
                            switch currentPage {
                            case 0:
                                WelcomePage()
                            case 1:
                                PermissionsPage(
                                    icon: "video.badge.checkmark",
                                    title: "Screen Recording",
                                    description: """
                                        EasyDemo needs permission to capture your screen \
                                        for creating professional recordings.
                                        """,
                                    pageNumber: 1,
                                    permissionGranted: $screenRecordingGranted
                                )
                            case 2:
                                PermissionsPage(
                                    icon: "camera.fill",
                                    title: "Camera Access",
                                    description: """
                                        Add your webcam as an overlay to personalize your \
                                        recordings and connect with viewers.
                                        """,
                                    pageNumber: 2,
                                    permissionGranted: $cameraAccessGranted
                                )
                            case 3:
                                PermissionsPage(
                                    icon: "mic.fill",
                                    title: "Microphone Access",
                                    description: """
                                        Record audio commentary with your screen recordings \
                                        for more engaging demos.
                                        """,
                                    pageNumber: 3,
                                    permissionGranted: $microphoneAccessGranted
                                )
                            default:
                                WelcomePage()
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        // Page indicators
                        HStack {
                            ForEach(0..<totalPages, id: \.self) { index in
                                let isActive = currentPage == index
                                let opacity = UIConstants.Onboarding.pageIndicatorOpacity
                                let activeSize = UIConstants.Onboarding.pageIndicatorActiveSize
                                let inactiveSize = UIConstants.Onboarding.pageIndicatorInactiveSize

                                Circle()
                                    .fill(isActive ? Color.primary : Color.primary.opacity(opacity))
                                    .frame(
                                        width: isActive ? activeSize : inactiveSize,
                                        height: isActive ? activeSize : inactiveSize
                                    )
                                    .animation(
                                        .spring(response: UIConstants.Onboarding.springShortResponse),
                                        value: currentPage
                                    )
                            }
                        }

                        // Navigation buttons
                        HStack(spacing: UIConstants.Onboarding.navigationSpacing) {
                            if currentPage > 0 {
                                Button(action: previousPage) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: UIConstants.Onboarding.buttonIconSize, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(
                                            width: UIConstants.Onboarding.backButtonSize,
                                            height: UIConstants.Onboarding.backButtonSize
                                        )
                                        .background(Color.primary.opacity(UIConstants.Colors.backgroundOpacity))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }

                            Spacer()

                            Button(action: nextPage) {
                                HStack {
                                    let buttonText = currentPage == totalPages - 1
                                        ? "Get Started"
                                        : "Next"
                                    let fontSize = UIConstants.Typography.buttonTextSize
                                    let smallIconSize = UIConstants.Onboarding.buttonIconSmallSize

                                    Text(buttonText)
                                        .font(.system(size: fontSize, weight: .semibold))

                                    if currentPage < totalPages - 1 {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: smallIconSize, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, UIConstants.Onboarding.buttonHorizontalPadding)
                                .padding(.vertical, UIConstants.Onboarding.buttonVerticalPadding)
                                .background(
                                    LinearGradient(
                                        colors: UIConstants.Colors.buttonGradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .opacity(canProceed ? 1.0 : 0.5)
                                .clipShape(Capsule())
                                .shadow(
                                    color: .blue.opacity(UIConstants.Onboarding.buttonShadowOpacity),
                                    radius: UIConstants.Onboarding.buttonShadowRadius,
                                    x: 0,
                                    y: UIConstants.Onboarding.buttonShadowY
                                )
                            }
                            .disabled(!canProceed)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, UIConstants.Onboarding.buttonPadding)
                        
                    }
                    
                }
                .frame(width: UIConstants.Onboarding.cardWidth)
            }
            .padding(.vertical, UIConstants.Onboarding.verticalPadding)
        }
        .frame(width: UIConstants.Onboarding.windowWidth, height: UIConstants.Onboarding.windowHeight)
    }

    // MARK: - Actions

    private func nextPage() {
        if currentPage < totalPages - 1 {
            withAnimation(.spring(
                response: UIConstants.Onboarding.springResponse,
                dampingFraction: UIConstants.Onboarding.springDamping
            )) {
                currentPage += 1
            }
        } else {
            // Complete onboarding and persist state
            onboardingManager.completeOnboarding()
        }
    }

    private func previousPage() {
        if currentPage > 0 {
            withAnimation(.spring(
                response: UIConstants.Onboarding.springResponse,
                dampingFraction: UIConstants.Onboarding.springDamping
            )) {
                currentPage -= 1
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
