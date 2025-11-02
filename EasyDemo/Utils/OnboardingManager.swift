//
//  OnboardingManager.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import Foundation
import Combine

/// Manages onboarding state using UserDefaults for persistence
final class OnboardingManager: ObservableObject {
    // MARK: - Singleton

    static let shared = OnboardingManager()

    // MARK: - Properties

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey)
        }
    }

    private let onboardingKey = "hasCompletedOnboarding"

    // MARK: - Initialization

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }

    // MARK: - Public Methods

    /// Marks onboarding as complete and persists to UserDefaults
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    /// Resets onboarding state (useful for testing or allowing users to see onboarding again)
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }

    /// Check if this is the first app launch
    var isFirstLaunch: Bool {
        !hasCompletedOnboarding
    }
}
