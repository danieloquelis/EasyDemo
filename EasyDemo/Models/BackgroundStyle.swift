//
//  BackgroundStyle.swift
//  EasyDemo
//
//  Created by Daniel Oquelis on 28.10.25.
//

import Foundation
import SwiftUI
import Combine

/// Represents different background styles for window capture
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

    // Default solid color background (dark orange)
    static let defaultSolidColor = BackgroundStyle.solidColor(Color(red: 1.0, green: 0.55, blue: 0.0))

    // Default gradient background
    static let defaultGradient = BackgroundStyle.gradient(
        colors: [
            Color(red: 0.1, green: 0.1, blue: 0.3),
            Color(red: 0.3, green: 0.2, blue: 0.5)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Manager for persisting custom image backgrounds using security-scoped bookmarks
@MainActor
class BackgroundImageManager: ObservableObject {
    @Published var customImageURLs: [URL] = []

    private let userDefaultsKey = "customBackgroundImageBookmarks"

    init() {
        loadCustomImages()
        validateImagePaths()
    }

    /// Load custom image URLs from UserDefaults using security-scoped bookmarks
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

    /// Save custom image URLs to UserDefaults as security-scoped bookmarks
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

    /// Validate all stored image paths and remove invalid ones
    func validateImagePaths() {
        let validURLs = customImageURLs.filter { url in
            // Check if file exists at the URL
            if url.isFileURL {
                let exists = FileManager.default.fileExists(atPath: url.path)
                return exists
            }
            return false
        }

        // Update if any URLs were removed
        if validURLs.count != customImageURLs.count {
            customImageURLs = validURLs
            saveCustomImages()
        }
    }

    /// Add a new custom image URL and create security-scoped bookmark
    func addCustomImage(_ url: URL) {
        // Avoid duplicates
        guard !customImageURLs.contains(url) else { return }

        // Verify file exists before adding
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File does not exist at path: \(url.path)")
            return
        }

        customImageURLs.append(url)
        saveCustomImages()
    }

    /// Remove a custom image URL
    func removeCustomImage(_ url: URL) {
        customImageURLs.removeAll { $0 == url }
        saveCustomImages()
    }
}
