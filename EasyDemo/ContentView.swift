//
//  ContentView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - Properties

    @StateObject private var onboardingManager = OnboardingManager.shared

    // MARK: - Body

    var body: some View {
        Group {
            if onboardingManager.hasCompletedOnboarding {
                SetupView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ContentView()
}
