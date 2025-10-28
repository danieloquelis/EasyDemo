//
//  InteractionEvent.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import CoreGraphics

/// Represents a user interaction event
enum InteractionEvent {
    case mouseClick(location: CGPoint, button: MouseButton)
    case mouseMove(location: CGPoint)
    case keyPress(key: String)

    enum MouseButton {
        case left
        case right
        case other
    }

    var timestamp: Date {
        Date()
    }

    var location: CGPoint? {
        switch self {
        case .mouseClick(let location, _), .mouseMove(let location):
            return location
        case .keyPress:
            return nil
        }
    }
}
