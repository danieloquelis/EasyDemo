import Foundation
import CoreGraphics

struct WebcamConfiguration: Codable {
    var isEnabled: Bool
    var shape: Shape
    var position: Position
    var size: CGFloat

    enum Shape: String, Codable, CaseIterable, Identifiable {
        case circle = "Circle"
        case roundedRectangle = "Rounded Rectangle"
        case squircle = "Squircle"

        var id: String { rawValue }
    }

    enum Position: String, Codable, CaseIterable, Identifiable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
        case custom = "Custom"

        var id: String { rawValue }

        func offset(in size: CGSize, webcamSize: CGFloat, padding: CGFloat) -> CGPoint {
            switch self {
            case .topLeft:
                return CGPoint(x: padding, y: padding)
            case .topRight:
                return CGPoint(x: size.width - webcamSize - padding, y: padding)
            case .bottomLeft:
                return CGPoint(x: padding, y: size.height - webcamSize - padding)
            case .bottomRight:
                return CGPoint(
                    x: size.width - webcamSize - padding,
                    y: size.height - webcamSize - padding
                )
            case .custom:
                return .zero
            }
        }
    }

    static let `default` = WebcamConfiguration(
        isEnabled: false,
        shape: .circle,
        position: .bottomRight,
        size: UIConstants.Size.webcamDefault
    )
}
