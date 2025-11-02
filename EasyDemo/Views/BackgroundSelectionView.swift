import SwiftUI
import UniformTypeIdentifiers

struct BackgroundSelectionView: View {
    @Binding var selectedBackground: BackgroundStyle
    @StateObject private var imageManager = BackgroundImageManager()

    @State private var showImagePicker = false
    @State private var showColorPicker = false
    @State private var showGradientEditor = false

    @State private var solidColor: Color = ColorPalette.defaultOrange
    @State private var gradientColor1: Color = ColorPalette.gradientDarkBlue
    @State private var gradientColor2: Color = ColorPalette.gradientPurple
    @State private var gradientStartPoint: UnitPoint = .topLeading
    @State private var gradientEndPoint: UnitPoint = .bottomTrailing

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Padding.small) {
            Text("Choose Background")
                .font(.headline)

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: UIConstants.Padding.small) {
                        defaultImageOptions
                        solidColorOption
                        gradientOption
                        customImageOptions
                        addImageButton
                    }
                    .padding(.horizontal, UIConstants.Padding.compact)
                    .padding(.vertical, UIConstants.Padding.compact)
                }
            }
            .frame(height: 130)
        }
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: handleImageSelection
        )
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
            initializeColors()
        }
    }

    private var solidColorOption: some View {
        Button {
            if isSolidColorSelected {
                showColorPicker = true
            } else {
                selectedBackground = .solidColor(solidColor)
            }
        } label: {
            SolidColorCard(color: solidColor, isSelected: isSolidColorSelected)
        }
        .buttonStyle(.plain)
    }

    private var gradientOption: some View {
        Button {
            if isGradientSelected {
                showGradientEditor = true
            } else {
                selectedBackground = .gradient(
                    colors: [gradientColor1, gradientColor2],
                    startPoint: gradientStartPoint,
                    endPoint: gradientEndPoint
                )
            }
        } label: {
            GradientCard(
                color1: gradientColor1,
                color2: gradientColor2,
                startPoint: gradientStartPoint,
                endPoint: gradientEndPoint,
                isSelected: isGradientSelected
            )
        }
        .buttonStyle(.plain)
    }

    private var defaultImageOptions: some View {
        ForEach(imageManager.defaultImageURLs) { defaultImage in
            Button {
                selectedBackground = .image(defaultImage.url)
            } label: {
                DefaultImageCard(
                    name: defaultImage.name,
                    url: defaultImage.url,
                    isSelected: isImageSelected(defaultImage.url)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var customImageOptions: some View {
        ForEach(imageManager.customImageURLs, id: \.self) { url in
            Button {
                selectedBackground = .image(url)
            } label: {
                CustomImageCard(url: url, isSelected: isImageSelected(url))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            imageManager.removeCustomImage(url)
                            if isImageSelected(url) {
                                selectedBackground = .solidColor(solidColor)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white, .red)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var addImageButton: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: UIConstants.Padding.tight) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)

                Text("Add Image")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: UIConstants.Size.thumbnailWidth / 2, height: UIConstants.Size.thumbnailHeight / 1.5)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(UIConstants.Size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.Size.cornerRadius)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var isSolidColorSelected: Bool {
        if case .solidColor = selectedBackground { return true }
        return false
    }

    private var isGradientSelected: Bool {
        if case .gradient = selectedBackground { return true }
        return false
    }

    private func isImageSelected(_ url: URL) -> Bool {
        if case .image(let selectedURL) = selectedBackground {
            return selectedURL == url
        }
        return false
    }

    private func handleImageSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                imageManager.addCustomImage(url)
                selectedBackground = .image(url)
            }
        case .failure:
            break
        }
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
