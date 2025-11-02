import Foundation
import SwiftUI

enum UIConstants {
    enum Padding {
        static let minimum: CGFloat = 80
        static let large: CGFloat = 40
        static let standard: CGFloat = 20
        static let medium: CGFloat = 16
        static let small: CGFloat = 12
        static let tight: CGFloat = 8
        static let compact: CGFloat = 4
        static let extraTight: CGFloat = 4
    }

    enum Size {
        static let thumbnailWidth: CGFloat = 200
        static let thumbnailHeight: CGFloat = 150
        static let iconSmall: CGFloat = 12
        static let iconMedium: CGFloat = 16
        static let iconLarge: CGFloat = 20
        static let webcamMin: CGFloat = 100
        static let webcamMax: CGFloat = 400
        static let webcamDefault: CGFloat = 200
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 2
    }

    enum Window {
        static let minWidth: CGFloat = 900
        static let minHeight: CGFloat = 600
        static let defaultWidth: CGFloat = 1200
        static let defaultHeight: CGFloat = 800
        static let sidebarMin: CGFloat = 300
        static let sidebarIdeal: CGFloat = 350
        static let sidebarMax: CGFloat = 400

        // Main window should initialize to maximum available screen size
        static let screenSizeMultiplier: CGFloat = 1.0  // 100% of available screen
        static let screenSizeMultiplierFallback: CGFloat = 0.7  // 70% if max not possible
    }

    enum Onboarding {
        static let windowWidth: CGFloat = 900
        static let windowHeight: CGFloat = 900
        static let cardWidth: CGFloat = 600
        static let verticalPadding: CGFloat = 100

        // Card styling
        static let cardCornerRadius: CGFloat = 32
        static let cardShadowRadius: CGFloat = 30
        static let cardShadowY: CGFloat = 20
        static let cardShadowOpacity: Double = 0.1

        // Page indicators
        static let pageIndicatorActiveSize: CGFloat = 8
        static let pageIndicatorInactiveSize: CGFloat = 6
        static let pageIndicatorOpacity: Double = 0.3

        // Navigation buttons
        static let backButtonSize: CGFloat = 44
        static let buttonIconSize: CGFloat = 16
        static let buttonIconSmallSize: CGFloat = 14
        static let buttonHorizontalPadding: CGFloat = 32
        static let buttonVerticalPadding: CGFloat = 14
        static let buttonShadowRadius: CGFloat = 15
        static let buttonShadowY: CGFloat = 8
        static let buttonShadowOpacity: Double = 0.4

        // Content spacing
        static let contentSpacing: CGFloat = 32
        static let featureRowSpacing: CGFloat = 20
        static let sectionSpacing: CGFloat = 16
        static let navigationSpacing: CGFloat = 16
        static let buttonPadding: CGFloat = 40

        // Welcome page
        static let appIconSize: CGFloat = 120
        static let appIconCornerRadius: CGFloat = 26
        static let appIconShadowRadius: CGFloat = 20
        static let appIconShadowY: CGFloat = 10
        static let appIconShadowOpacity: Double = 0.2

        // Permissions page
        static let permissionIconCircleSize: CGFloat = 120
        static let permissionIconSize: CGFloat = 50
        static let permissionButtonMaxWidth: CGFloat = 280

        // Feature row
        static let featureIconSize: CGFloat = 24
        static let featureIconWidth: CGFloat = 40

        // Animation
        static let gradientAnimationDuration: Double = 8.0
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.8
        static let springShortResponse: Double = 0.3
    }

    enum Typography {
        // Onboarding
        static let welcomeTitleSize: CGFloat = 36
        static let welcomeSubtitleSize: CGFloat = 18
        static let permissionsTitleSize: CGFloat = 32
        static let permissionsDescriptionSize: CGFloat = 16
        static let featureTitleSize: CGFloat = 16
        static let featureDescriptionSize: CGFloat = 14
        static let buttonTextSize: CGFloat = 16
    }

    enum Colors {
        // Brand colors (from app icon)
        static let brandBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
        static let brandPurple = Color(red: 0.5, green: 0.3, blue: 0.9)
        static let brandPurpleDark = Color(red: 0.4, green: 0.3, blue: 0.9)
        static let brandCoral = Color(red: 1.0, green: 0.4, blue: 0.3)
        static let brandOrange = Color(red: 1.0, green: 0.6, blue: 0.2)

        // Gradient colors
        static let gradientColors: [Color] = [
            brandBlue,
            brandPurple,
            brandCoral,
            brandOrange
        ]

        // Button gradients
        static let buttonGradientColors: [Color] = [
            brandBlue,
            brandPurpleDark
        ]

        // Transparency values
        static let materialOpacity: Double = 0.2
        static let backgroundOpacity: Double = 0.1
    }

    enum Scale {
        static let min: Double = 0.2
        static let max: Double = 1.0
        static let `default`: Double = 0.8
        static let step: Double = 0.05
    }

    enum Animation {
        static let standardDuration: Double = 0.2
        static let slowDuration: Double = 0.3
    }
}
