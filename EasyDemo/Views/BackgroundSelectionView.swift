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
    @State private var scrollOffset: CGFloat = 0
    @State private var isHovering = false
    @State private var canScrollLeft = false
    @State private var canScrollRight = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose Background")
                .font(.headline)

            ZStack(alignment: .center) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BackgroundStyle.presets) { style in
                                BackgroundPreviewCard(
                                    style: style,
                                    isSelected: style.id == selectedBackground.id
                                )
                                .id(style.id)
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
                            .id("custom")
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 2)
                    }
                    .frame(height: 120)

                    // Left chevron
                    if isHovering && canScrollLeft {
                        HStack {
                            Button {
                                scrollToPrevious(proxy: proxy)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)

                            Spacer()
                        }
                    }

                    // Right chevron
                    if isHovering && canScrollRight {
                        HStack {
                            Spacer()

                            Button {
                                scrollToNext(proxy: proxy)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                    }
                }
            }
            .onHover { hovering in
                isHovering = hovering
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

    private func scrollToPrevious(proxy: ScrollViewProxy) {
        guard let currentIndex = BackgroundStyle.presets.firstIndex(where: { $0.id == selectedBackground.id }) else { return }

        if currentIndex > 0 {
            let previousStyle = BackgroundStyle.presets[currentIndex - 1]
            withAnimation {
                proxy.scrollTo(previousStyle.id, anchor: .center)
            }
            canScrollLeft = currentIndex > 1
            canScrollRight = true
        } else {
            canScrollLeft = false
        }
    }

    private func scrollToNext(proxy: ScrollViewProxy) {
        guard let currentIndex = BackgroundStyle.presets.firstIndex(where: { $0.id == selectedBackground.id }) else {
            if !BackgroundStyle.presets.isEmpty {
                withAnimation {
                    proxy.scrollTo(BackgroundStyle.presets[0].id, anchor: .center)
                }
            }
            return
        }

        if currentIndex < BackgroundStyle.presets.count - 1 {
            let nextStyle = BackgroundStyle.presets[currentIndex + 1]
            withAnimation {
                proxy.scrollTo(nextStyle.id, anchor: .center)
            }
            canScrollLeft = true
            canScrollRight = currentIndex < BackgroundStyle.presets.count - 2
        } else {
            withAnimation {
                proxy.scrollTo("custom", anchor: .center)
            }
            canScrollRight = false
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
