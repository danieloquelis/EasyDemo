//
//  BackgroundStyle.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import SwiftUI

/// Represents different background styles for window capture
enum BackgroundStyle: Hashable, Identifiable {
    case solidColor(Color)
    case gradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint)
    case blur
    case image(URL)

    var id: String {
        switch self {
        case .solidColor(let color):
            return "solid_\(color.description)"
        case .gradient(let colors, _, _):
            return "gradient_\(colors.map { $0.description }.joined())"
        case .blur:
            return "blur"
        case .image(let url):
            return "image_\(url.absoluteString)"
        }
    }

    var displayName: String {
        switch self {
        case .solidColor:
            return "Solid Color"
        case .gradient:
            return "Gradient"
        case .blur:
            return "Blurred Wallpaper"
        case .image:
            return "Custom Image"
        }
    }

    // Predefined background styles
    static let presets: [BackgroundStyle] = [
        .solidColor(.black),
        .solidColor(.white),
        .solidColor(Color(red: 0.1, green: 0.1, blue: 0.12)),
        .gradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.3),
                Color(red: 0.3, green: 0.2, blue: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        .gradient(
            colors: [
                Color(red: 0.9, green: 0.4, blue: 0.3),
                Color(red: 0.9, green: 0.6, blue: 0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        .blur
    ]
}
