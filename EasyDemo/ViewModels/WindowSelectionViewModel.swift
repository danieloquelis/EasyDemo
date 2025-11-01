//
//  WindowSelectionViewModel.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for window selection screen
@MainActor
class WindowSelectionViewModel: ObservableObject {
    @Published var selectedWindow: WindowInfo?
    @Published var isRefreshing = false

    let windowCapture = WindowCapture()

    init() {
        Task {
            // Wait for permission check to complete first
            await windowCapture.checkScreenRecordingPermission()
            // Then automatically load windows if permission is granted
            if windowCapture.hasScreenRecordingPermission {
                await refreshWindows()
            }
        }
    }

    func refreshWindows() async {
        isRefreshing = true
        await windowCapture.enumerateWindows()
        isRefreshing = false
    }

    func selectWindow(_ window: WindowInfo) {
        self.selectedWindow = window
    }
}
