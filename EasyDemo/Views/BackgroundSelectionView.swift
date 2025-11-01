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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UIConstants.Padding.small) {
                    solidColorOption
                    gradientOption
                    customImageOptions
                    addImageButton
                }
                .padding(.horizontal, UIConstants.Padding.compact)
                .padding(.vertical, 2)
            }
            .frame(height: 120)
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
        SolidColorCard(color: solidColor, isSelected: isSolidColorSelected)
            .onTapGesture {
                selectedBackground = .solidColor(solidColor)
            }
            .overlay(alignment: .topTrailing) {
                if isSolidColorSelected {
                    editButton {
                        showColorPicker = true
                    }
                }
            }
    }

    private var gradientOption: some View {
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
                editButton {
                    showGradientEditor = true
                }
            }
        }
    }

    private var customImageOptions: some View {
        ForEach(imageManager.customImageURLs, id: \.self) { url in
            CustomImageCard(url: url, isSelected: isImageSelected(url))
                .onTapGesture {
                    selectedBackground = .image(url)
                }
                .overlay(alignment: .topTrailing) {
                    deleteButton {
                        imageManager.removeCustomImage(url)
                        if isImageSelected(url) {
                            selectedBackground = .solidColor(solidColor)
                        }
                    }
                }
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

    private func editButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: UIConstants.Padding.standard))
                .foregroundColor(.white)
                .background(Circle().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .padding(6)
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: UIConstants.Padding.standard))
                .foregroundColor(.white)
                .background(Circle().fill(Color.red))
        }
        .buttonStyle(.plain)
        .padding(6)
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
