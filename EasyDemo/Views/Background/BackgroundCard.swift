import SwiftUI

struct SolidColorCard: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: UIConstants.Padding.tight) {
            Rectangle()
                .fill(color)
                .frame(width: UIConstants.Size.thumbnailWidth / 2, height: UIConstants.Size.thumbnailHeight / 1.5)
                .cornerRadius(UIConstants.Size.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.Size.cornerRadius)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            Text("Solid Color")
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
    }
}

struct GradientCard: View {
    let color1: Color
    let color2: Color
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    let isSelected: Bool

    var body: some View {
        VStack(spacing: UIConstants.Padding.tight) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color1, color2],
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                )
                .frame(width: UIConstants.Size.thumbnailWidth / 2, height: UIConstants.Size.thumbnailHeight / 1.5)
                .cornerRadius(UIConstants.Size.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.Size.cornerRadius)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

            Text("Gradient")
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
    }
}

struct CustomImageCard: View {
    let url: URL
    let isSelected: Bool
    @State private var loadedImage: NSImage?

    var body: some View {
        VStack(spacing: UIConstants.Padding.tight) {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIConstants.Size.thumbnailWidth / 2, height: UIConstants.Size.thumbnailHeight / 1.5)
                    .cornerRadius(UIConstants.Size.cornerRadius)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.Size.cornerRadius)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: UIConstants.Size.thumbnailWidth / 2, height: UIConstants.Size.thumbnailHeight / 1.5)
                    .cornerRadius(UIConstants.Size.cornerRadius)
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
