import Foundation
import SwiftUI
import Combine

struct DefaultBackgroundImage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}

enum BackgroundStyle: Hashable, Identifiable {
    case solidColor(Color)
    case gradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint)
    case image(URL)

    var id: String {
        switch self {
        case .solidColor(let color):
            return "solid_\(color.description)"
        case .gradient(let colors, _, _):
            return "gradient_\(colors.map { $0.description }.joined())"
        case .image(let url):
            return "image_\(url.absoluteString)"
        }
    }

    var displayName: String {
        switch self {
        case .solidColor:
            return "Solid Color"
        case .gradient:
            return "Gradient"
        case .image:
            return "Custom Image"
        }
    }

    static let defaultSolidColor = BackgroundStyle.solidColor(ColorPalette.defaultOrange)

    static let defaultGradient = BackgroundStyle.gradient(
        colors: [ColorPalette.gradientDarkBlue, ColorPalette.gradientPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var defaultBigSur: BackgroundStyle {
        if let bigSurURL = Bundle.main.url(forResource: "custom-wallpaper", withExtension: "jpg") {
            return .image(bigSurURL)
        }
        return defaultSolidColor
    }
}

@MainActor
class BackgroundImageManager: ObservableObject {
    @Published var customImageURLs: [URL] = []
    @Published var defaultImageURLs: [DefaultBackgroundImage] = []

    private let userDefaultsKey = "customBackgroundImageBookmarks"

    init() {
        loadDefaultImages()
        loadCustomImages()
        validateImagePaths()
    }

    private func loadDefaultImages() {
        // Add Big Sur wallpaper from Resources
        if let bigSurURL = Bundle.main.url(forResource: "custom-wallpaper", withExtension: "jpg") {
            defaultImageURLs.append(DefaultBackgroundImage(name: "Big Sur", url: bigSurURL))
        }
    }

    private func loadCustomImages() {
        if let bookmarksData = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Data] {
            customImageURLs = bookmarksData.compactMap { bookmarkData in
                var isStale = false
                guard let url = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) else {
                    return nil
                }

                // If bookmark is stale but file exists, we'll recreate it later
                if !isStale || FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
                return nil
            }
        }
    }

    private func saveCustomImages() {
        let bookmarks = customImageURLs.compactMap { url -> Data? in
            do {
                return try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                print("Failed to create bookmark for \(url): \(error)")
                return nil
            }
        }
        UserDefaults.standard.set(bookmarks, forKey: userDefaultsKey)
    }

    func validateImagePaths() {
        let validURLs = customImageURLs.filter { url in
            if url.isFileURL {
                let exists = FileManager.default.fileExists(atPath: url.path)
                return exists
            }
            return false
        }

        if validURLs.count != customImageURLs.count {
            customImageURLs = validURLs
            saveCustomImages()
        }
    }

    func addCustomImage(_ url: URL) {
        guard !customImageURLs.contains(url) else { return }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File does not exist at path: \(url.path)")
            return
        }

        customImageURLs.append(url)
        saveCustomImages()
    }

    func removeCustomImage(_ url: URL) {
        customImageURLs.removeAll { $0 == url }
        saveCustomImages()
    }
}
