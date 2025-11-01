import SwiftUI

enum ColorPalette {
    static let defaultOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
    static let gradientDarkBlue = Color(red: 0.1, green: 0.1, blue: 0.3)
    static let gradientPurple = Color(red: 0.3, green: 0.2, blue: 0.5)

    enum Shadow {
        static let standard = Color.black.opacity(0.7)
        static let light = Color.black.opacity(0.3)
        static let radius: CGFloat = 15
        static let offset = CGSize(width: 0, height: 8)
    }

    enum Overlay {
        static let darkBackground = Color.black.opacity(0.5)
    }
}
