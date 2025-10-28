//
//  WindowInfo.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import CoreGraphics

/// Represents information about a macOS window
struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let ownerName: String
    let windowName: String?
    let bounds: CGRect
    let layer: Int
    let alpha: CGFloat

    var displayName: String {
        if let name = windowName, !name.isEmpty {
            return "\(ownerName) - \(name)"
        }
        return ownerName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
