//
//  BackgroundSelectionView.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for selecting background style
struct BackgroundSelectionView: View {
    @Binding var selectedBackground: BackgroundStyle
    @State private var showImagePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Background")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BackgroundStyle.presets) { style in
                        BackgroundPreviewCard(
                            style: style,
                            isSelected: style.id == selectedBackground.id
                        )
                        .onTapGesture {
                            selectedBackground = style
                        }
                    }

                    // Custom image button
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)

                            Text("Custom Image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 100, height: 100)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedBackground = .image(url)
                }
            case .failure(let error):
                print("Failed to select image: \(error)")
            }
        }
    }
}

/// Preview card for background style
struct BackgroundPreviewCard: View {
    let style: BackgroundStyle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Preview
            backgroundPreview
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            // Label
            Text(style.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        Group {
            switch style {
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
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                }

            case .image(let url):
                if let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                }
            }
        }
        .clipped()
    }
}

#Preview {
    BackgroundSelectionView(selectedBackground: .constant(.solidColor(.black)))
        .padding()
}
