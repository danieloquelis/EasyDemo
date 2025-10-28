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
        ZStack {
            // Background layer - contained and clipped
            backgroundView

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
                    .padding(40)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task {
            await preview.capturePreview(window: window)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        Group {
            switch backgroundStyle {
            case .solidColor(let color):
                Rectangle()
                    .fill(color)

            case .gradient(let colors, let startPoint, let endPoint):
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: startPoint,
                            endPoint: endPoint
                        )
                    )

            case .blur:
                Rectangle()
                    .fill(Color.gray.opacity(0.3))

            case .image(let url):
                if let nsImage = NSImage(contentsOf: url),
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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
