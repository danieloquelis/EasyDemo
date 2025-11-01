import Foundation
import CoreImage
import CoreGraphics
import AppKit
import SwiftUI

final class BackgroundRenderer {
    private var cachedImage: CIImage?
    private var cachedURL: URL?

    func createBackground(size: CGSize, style: BackgroundStyle) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)

        switch style {
        case .solidColor(let color):
            return createSolidColor(color: color, rect: rect)
        case .gradient(let colors, let startPoint, let endPoint):
            return createGradient(colors: colors, startPoint: startPoint, endPoint: endPoint, size: size, rect: rect)
        case .image(let url):
            return createImageBackground(url: url, size: size, rect: rect)
        }
    }

    private func createSolidColor(color: Color, rect: CGRect) -> CIImage {
        guard let cgColor = color.cgColor else {
            return CIImage(color: CIColor.black).cropped(to: rect)
        }
        return CIImage(color: CIColor(cgColor: cgColor)).cropped(to: rect)
    }

    private func createGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint, size: CGSize, rect: CGRect) -> CIImage {
        let ciColors = colors.compactMap { $0.cgColor }.map { CIColor(cgColor: $0) }
        guard ciColors.count >= 2,
              let filter = CIFilter(name: "CILinearGradient") else {
            return CIImage(color: CIColor.black).cropped(to: rect)
        }

        let startVector = CIVector(
            x: startPoint.x * size.width,
            y: (1 - startPoint.y) * size.height
        )
        let endVector = CIVector(
            x: endPoint.x * size.width,
            y: (1 - endPoint.y) * size.height
        )

        filter.setValue(ciColors[0], forKey: "inputColor0")
        filter.setValue(ciColors[1], forKey: "inputColor1")
        filter.setValue(startVector, forKey: "inputPoint0")
        filter.setValue(endVector, forKey: "inputPoint1")

        return filter.outputImage?.cropped(to: rect) ?? CIImage(color: CIColor.black).cropped(to: rect)
    }

    private func createImageBackground(url: URL, size: CGSize, rect: CGRect) -> CIImage {
        let baseImage: CIImage?

        if let cached = cachedImage, cachedURL == url {
            baseImage = cached
        } else {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if let nsImage = NSImage(contentsOf: url),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                baseImage = CIImage(cgImage: cgImage)
                cachedImage = baseImage
                cachedURL = url
            } else {
                baseImage = nil
            }
        }

        guard let ciImage = baseImage else {
            return CIImage(color: CIColor.black).cropped(to: rect)
        }

        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let scale = max(scaleX, scaleY)

        return ciImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: rect)
    }
}
