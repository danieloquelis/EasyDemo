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
        static let sidebarMin: CGFloat = 300
        static let sidebarIdeal: CGFloat = 350
        static let sidebarMax: CGFloat = 400
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
