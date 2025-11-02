//
//  AnimatedGradientBackground.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 01.11.25.
//

import SwiftUI

struct AnimatedGradientBackground: View {
    // MARK: - Properties

    @State private var animateGradient = false

    // MARK: - Body

    var body: some View {
        LinearGradient(
            colors: UIConstants.Colors.gradientColors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: UIConstants.Onboarding.gradientAnimationDuration)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient = true
            }
        }
    }
}

#Preview {
    AnimatedGradientBackground()
}
