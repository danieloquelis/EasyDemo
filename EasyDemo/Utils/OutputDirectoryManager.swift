//
//  OutputDirectoryManager.swift
//  EasyDemo
//
//  Manages security-scoped access to custom output directories
//

import Foundation
import Combine

@MainActor
class OutputDirectoryManager: ObservableObject {
    @Published var customOutputDirectory: URL?
    
    private let userDefaultsKey = "outputDirectoryBookmark"
    private var accessCount: Int = 0
    
    init() {
        loadOutputDirectory()
    }
    
    /// Load the saved output directory from UserDefaults
    private func loadOutputDirectory() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            print("Failed to resolve output directory bookmark")
            return
        }
        
        // Verify the directory still exists
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            customOutputDirectory = url
            
            // If bookmark is stale, recreate it
            if isStale {
                saveOutputDirectory(url)
            }
        } else {
            // Directory no longer exists, clear the bookmark
            clearOutputDirectory()
        }
    }
    
    /// Save a new output directory and create a security-scoped bookmark
    func saveOutputDirectory(_ url: URL) {
        // Verify it's a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("Selected path is not a valid directory: \(url.path)")
            return
        }
        
        // Start accessing the security-scoped resource first
        // Note: fileImporter provides a security-scoped URL that we must access
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        
        do {
            // Create the security-scoped bookmark while we have access
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: userDefaultsKey)
            customOutputDirectory = url
            print("✅ Successfully saved output directory bookmark: \(url.path)")
        } catch {
            print("❌ Failed to create bookmark for output directory: \(error)")
            print("   URL: \(url)")
            print("   Error details: \(error.localizedDescription)")
            
            // Try without the read-only flag as a fallback
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(bookmarkData, forKey: userDefaultsKey)
                customOutputDirectory = url
                print("✅ Successfully saved bookmark on second attempt")
            } catch {
                print("❌ Second attempt also failed: \(error)")
            }
        }
        
        // Stop accessing after creating bookmark
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    /// Clear the saved output directory
    func clearOutputDirectory() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        customOutputDirectory = nil
    }
    
    /// Start accessing the security-scoped resource (with reference counting)
    func startAccessing() -> Bool {
        guard let url = customOutputDirectory else {
            return false
        }
        
        // Increment access count and start accessing if this is the first request
        accessCount += 1
        
        if accessCount == 1 {
            let didStart = url.startAccessingSecurityScopedResource()
            if !didStart {
                print("❌ Failed to start accessing security-scoped resource for: \(url.path)")
                accessCount = 0
                return false
            }
            print("🔓 Started accessing security-scoped directory (count: \(accessCount))")
        } else {
            print("🔓 Reusing security-scoped access (count: \(accessCount))")
        }
        
        return true
    }
    
    /// Stop accessing the security-scoped resource (with reference counting)
    func stopAccessing() {
        guard let url = customOutputDirectory, accessCount > 0 else {
            return
        }
        
        accessCount -= 1
        
        if accessCount == 0 {
            url.stopAccessingSecurityScopedResource()
            print("🔒 Stopped accessing security-scoped directory (count: \(accessCount))")
        } else {
            print("🔒 Decreased access count (count: \(accessCount))")
        }
    }
    
    /// Get the directory URL to use for recording (custom or default temp)
    func getRecordingDirectory() -> URL? {
        return customOutputDirectory
    }
}

