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
    @StateObject private var imageManager = BackgroundImageManager()

    @State private var showImagePicker = false
    @State private var showColorPicker = false
    @State private var showGradientEditor = false

    // Editable color states
    @State private var solidColor: Color = Color(red: 1.0, green: 0.55, blue: 0.0)
    @State private var gradientColor1: Color = Color(red: 0.1, green: 0.1, blue: 0.3)
    @State private var gradientColor2: Color = Color(red: 0.3, green: 0.2, blue: 0.5)
    @State private var gradientStartPoint: UnitPoint = .topLeading
    @State private var gradientEndPoint: UnitPoint = .bottomTrailing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Background")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Solid color option with edit
                    SolidColorCard(
                        color: solidColor,
                        isSelected: isSolidColorSelected
                    )
                    .onTapGesture {
                        selectedBackground = .solidColor(solidColor)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSolidColorSelected {
                            Button {
                                showColorPicker = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.accentColor))
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                    }

                    // Gradient option with edit
                    GradientCard(
                        color1: gradientColor1,
                        color2: gradientColor2,
                        startPoint: gradientStartPoint,
                        endPoint: gradientEndPoint,
                        isSelected: isGradientSelected
                    )
                    .onTapGesture {
                        selectedBackground = .gradient(
                            colors: [gradientColor1, gradientColor2],
                            startPoint: gradientStartPoint,
                            endPoint: gradientEndPoint
                        )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isGradientSelected {
                            Button {
                                showGradientEditor = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.accentColor))
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                    }

                    // Custom image previews
                    ForEach(imageManager.customImageURLs, id: \.self) { url in
                        CustomImageCard(
                            url: url,
                            isSelected: isImageSelected(url)
                        )
                        .onTapGesture {
                            selectedBackground = .image(url)
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                imageManager.removeCustomImage(url)
                                // If this was selected, switch to default
                                if isImageSelected(url) {
                                    selectedBackground = .solidColor(solidColor)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.red))
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                    }

                    // Add custom image button
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)

                            Text("Add Image")
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
                .padding(.vertical, 2)
            }
            .frame(height: 120)
        }
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Start accessing security-scoped resource
                    let didStartAccessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if didStartAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    imageManager.addCustomImage(url)
                    selectedBackground = .image(url)
                }
            case .failure(let error):
                print("Failed to select image: \(error)")
            }
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(color: $solidColor) {
                selectedBackground = .solidColor(solidColor)
            }
        }
        .sheet(isPresented: $showGradientEditor) {
            GradientEditorSheet(
                color1: $gradientColor1,
                color2: $gradientColor2,
                startPoint: $gradientStartPoint,
                endPoint: $gradientEndPoint
            ) {
                selectedBackground = .gradient(
                    colors: [gradientColor1, gradientColor2],
                    startPoint: gradientStartPoint,
                    endPoint: gradientEndPoint
                )
            }
        }
        .onAppear {
            // Initialize colors from selected background if applicable
            initializeColors()
        }
    }

    private var isSolidColorSelected: Bool {
        if case .solidColor = selectedBackground {
            return true
        }
        return false
    }

    private var isGradientSelected: Bool {
        if case .gradient = selectedBackground {
            return true
        }
        return false
    }

    private func isImageSelected(_ url: URL) -> Bool {
        if case .image(let selectedURL) = selectedBackground {
            return selectedURL == url
        }
        return false
    }

    private func initializeColors() {
        switch selectedBackground {
        case .solidColor(let color):
            solidColor = color
        case .gradient(let colors, let start, let end):
            if colors.count >= 2 {
                gradientColor1 = colors[0]
                gradientColor2 = colors[1]
            }
            gradientStartPoint = start
            gradientEndPoint = end
        case .image:
            break
        }
    }
}

/// Solid color preview card
struct SolidColorCard: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            Text("Solid Color")
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
    }
}

/// Gradient preview card
struct GradientCard: View {
    let color1: Color
    let color2: Color
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color1, color2],
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                )
                .frame(width: 100, height: 100)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            Text("Gradient")
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
    }
}

/// Custom image preview card
struct CustomImageCard: View {
    let url: URL
    let isSelected: Bool
    @State private var loadedImage: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 100, height: 100)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.white)
                    )
            }

            Text("Custom Image")
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
        .task {
            loadImage()
        }
    }

    private func loadImage() {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let image = NSImage(contentsOf: url) {
            loadedImage = image
        }
    }
}

/// Color picker sheet for solid color
struct ColorPickerSheet: View {
    @Binding var color: Color
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Color")
                .font(.title2)
                .fontWeight(.bold)

            ColorPicker("Background Color", selection: $color, supportsOpacity: false)
                .padding()

            // Preview
            Rectangle()
                .fill(color)
                .frame(height: 150)
                .cornerRadius(12)
                .padding()

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

/// Gradient editor sheet
struct GradientEditorSheet: View {
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var startPoint: UnitPoint
    @Binding var endPoint: UnitPoint
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Gradient direction options
    private let directions: [(String, UnitPoint, UnitPoint)] = [
        ("Top to Bottom", .top, .bottom),
        ("Left to Right", .leading, .trailing),
        ("Diagonal ↘", .topLeading, .bottomTrailing),
        ("Diagonal ↙", .topTrailing, .bottomLeading)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Gradient")
                .font(.title2)
                .fontWeight(.bold)

            // Color pickers
            VStack(alignment: .leading, spacing: 12) {
                ColorPicker("Start Color", selection: $color1, supportsOpacity: false)
                ColorPicker("End Color", selection: $color2, supportsOpacity: false)
            }
            .padding()

            // Direction picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Direction")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(directions, id: \.0) { direction in
                        Button(direction.0) {
                            startPoint = direction.1
                            endPoint = direction.2
                        }
                        .buttonStyle(.bordered)
                        .tint(startPoint == direction.1 && endPoint == direction.2 ? .accentColor : .gray)
                    }
                }
            }
            .padding()

            // Preview
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color1, color2],
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                )
                .frame(height: 150)
                .cornerRadius(12)
                .padding()

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
    }
}

#Preview {
    BackgroundSelectionView(selectedBackground: .constant(.solidColor(.black)))
        .padding()
}
