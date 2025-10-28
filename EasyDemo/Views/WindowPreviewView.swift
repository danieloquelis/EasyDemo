//
//  WindowPreviewView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI

/// View for previewing selected window with background
struct WindowPreviewView: View {
    let window: WindowInfo
    let backgroundStyle: BackgroundStyle
    @StateObject private var preview = WindowPreview()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer
                backgroundView
                    .ignoresSafeArea()

                // Window preview layer
                if let image = preview.previewImage {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(
                            color: .black.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                        .frame(
                            maxWidth: geometry.size.width * 0.8,
                            maxHeight: geometry.size.height * 0.8
                        )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Capturing preview...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await preview.capturePreview(window: window)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch backgroundStyle {
        case .solidColor(let color):
            color

        case .gradient(let colors, let startPoint, let endPoint):
            LinearGradient(
                colors: colors,
                startPoint: startPoint,
                endPoint: endPoint
            )

        case .blur:
            // Placeholder for blurred wallpaper (will implement with actual wallpaper later)
            Color.gray.opacity(0.3)
                .blur(radius: 50)

        case .image(let url):
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
            } else {
                Color.gray
            }
        }
    }
}

#Preview {
    WindowPreviewView(
        window: WindowInfo(
            id: 1,
            ownerName: "Preview",
            windowName: "Test Window",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            alpha: 1.0,
            scWindow: nil
        ),
        backgroundStyle: .solidColor(.black)
    )
}
