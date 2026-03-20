import Foundation
import CoreGraphics
import ScreenCaptureKit

/// Represents information about a macOS display
struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let width: Int
    let height: Int
    let scDisplay: SCDisplay?

    var displayName: String {
        if CGDisplayIsMain(id) != 0 {
            return "Main Display (\(width) x \(height))"
        }
        return "Display (\(width) x \(height))"
    }

    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents the source to capture: either a window or an entire display
enum CaptureSource: Identifiable, Hashable {
    case window(WindowInfo)
    case display(DisplayInfo)

    var id: String {
        switch self {
        case .window(let info): return "window-\(info.id)"
        case .display(let info): return "display-\(info.id)"
        }
    }

    var displayName: String {
        switch self {
        case .window(let info): return info.displayName
        case .display(let info): return info.displayName
        }
    }

    var bounds: CGRect {
        switch self {
        case .window(let info): return info.bounds
        case .display(let info): return info.bounds
        }
    }

    var isDisplay: Bool {
        if case .display = self { return true }
        return false
    }
}
