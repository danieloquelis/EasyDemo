import Foundation
import CoreImage
import CoreGraphics
import AVFoundation

final class VideoComposer {
    private let ciContext = CIContext()
    private let backgroundRenderer = BackgroundRenderer()
    private let webcamRenderer = WebcamOverlayRenderer()

    func composeFrame(
        windowBuffer: CVPixelBuffer,
        configuration: RecordingConfiguration,
        targetOutputSize: CGSize,
        scaleFactor: CGFloat,
        webcamFrame: CIImage?,
        frameCount: Int64
    ) -> CVPixelBuffer? {
        let windowWidth = CVPixelBufferGetWidth(windowBuffer)
        let windowHeight = CVPixelBufferGetHeight(windowBuffer)

        let marginInPoints: CGFloat = UIConstants.Padding.minimum
        let marginInPixels = Int(marginInPoints * 2 * scaleFactor)

        let nativeWidth = windowWidth + marginInPixels
        let nativeHeight = windowHeight + marginInPixels

        let (finalWidth, finalHeight, needsUpscaling) = calculateOutputDimensions(
            nativeWidth: nativeWidth,
            nativeHeight: nativeHeight,
            targetSize: targetOutputSize
        )

        guard let outputBuffer = createPixelBuffer(width: finalWidth, height: finalHeight) else {
            return nil
        }

        let nativeBackgroundImage = backgroundRenderer.createBackground(
            size: CGSize(width: nativeWidth, height: nativeHeight),
            style: configuration.background
        )

        let windowImage = CIImage(cvPixelBuffer: windowBuffer)
        let composited = composeWindow(
            windowImage: windowImage,
            background: nativeBackgroundImage,
            scale: configuration.windowScale,
            canvasSize: CGSize(width: nativeWidth, height: nativeHeight),
            webcamFrame: webcamFrame,
            webcamConfig: configuration.webcam,
            scaleFactor: scaleFactor,
            applyCornerRadius: configuration.source.isDisplay
        )

        let finalComposited = upscaleIfNeeded(
            image: composited,
            needsUpscaling: needsUpscaling,
            nativeWidth: nativeWidth,
            nativeHeight: nativeHeight,
            finalWidth: finalWidth,
            finalHeight: finalHeight,
            frameCount: frameCount
        )

        ciContext.render(finalComposited, to: outputBuffer)
        return outputBuffer
    }

    private func calculateOutputDimensions(
        nativeWidth: Int,
        nativeHeight: Int,
        targetSize: CGSize
    ) -> (width: Int, height: Int, needsUpscaling: Bool) {
        if targetSize != .zero &&
           (Int(targetSize.width) != nativeWidth || Int(targetSize.height) != nativeHeight) {
            return (Int(targetSize.width), Int(targetSize.height), true)
        }
        return (nativeWidth, nativeHeight, false)
    }

    private func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &outputBuffer
        )
        return outputBuffer
    }

    private func composeWindow(
        windowImage: CIImage,
        background: CIImage,
        scale: Double,
        canvasSize: CGSize,
        webcamFrame: CIImage?,
        webcamConfig: WebcamConfiguration,
        scaleFactor: CGFloat,
        applyCornerRadius: Bool = false
    ) -> CIImage {
        let windowScale = CGFloat(scale)
        var scaledWindow = windowImage.transformed(
            by: CGAffineTransform(scaleX: windowScale, y: windowScale)
        )

        let scaledWidth = windowImage.extent.width * windowScale
        let scaledHeight = windowImage.extent.height * windowScale

        // Apply rounded corners for display captures
        if applyCornerRadius {
            let cornerRadius = 10.0 * scaleFactor
            scaledWindow = applyRoundedCorners(
                to: scaledWindow,
                cornerRadius: cornerRadius
            )
        }

        let xOffset = (canvasSize.width - scaledWidth) / 2
        let yOffset = (canvasSize.height - scaledHeight) / 2
        let centeredWindow = scaledWindow.transformed(
            by: CGAffineTransform(translationX: xOffset, y: yOffset)
        )

        var composited = centeredWindow.composited(over: background)

        if webcamConfig.isEnabled, let frame = webcamFrame {
            let webcamOverlay = webcamRenderer.createOverlay(
                webcamFrame: frame,
                configuration: webcamConfig,
                canvasSize: canvasSize,
                scaleFactor: scaleFactor
            )
            composited = webcamOverlay.composited(over: composited)
        }

        return composited
    }

    private func applyRoundedCorners(to image: CIImage, cornerRadius: CGFloat) -> CIImage {
        let rect = image.extent
        guard let mask = createRoundedRectMask(
            size: rect.size,
            cornerRadius: cornerRadius
        ) else {
            return image
        }

        let positionedMask = mask.transformed(
            by: CGAffineTransform(translationX: rect.origin.x, y: rect.origin.y)
        )
        let clearBg = CIImage(color: CIColor.clear).cropped(to: rect)

        return image.applyingFilter("CIBlendWithMask", parameters: [
            "inputBackgroundImage": clearBg,
            "inputMaskImage": positionedMask
        ])
    }

    private func createRoundedRectMask(size: CGSize, cornerRadius: CGFloat) -> CIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        let rect = CGRect(origin: .zero, size: size)

        // Fill black (masked out)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(rect)

        // Draw white rounded rect (visible area)
        ctx.setFillColor(gray: 1, alpha: 1)
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        ctx.addPath(path)
        ctx.fillPath()

        guard let cgImage = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private func upscaleIfNeeded(
        image: CIImage,
        needsUpscaling: Bool,
        nativeWidth: Int,
        nativeHeight: Int,
        finalWidth: Int,
        finalHeight: Int,
        frameCount: Int64
    ) -> CIImage {
        guard needsUpscaling else { return image }

        let nativeAspect = CGFloat(nativeWidth) / CGFloat(nativeHeight)
        let targetAspect = CGFloat(finalWidth) / CGFloat(finalHeight)

        let scaledWidth: CGFloat
        let scaledHeight: CGFloat

        if nativeAspect > targetAspect {
            scaledWidth = CGFloat(finalWidth)
            scaledHeight = scaledWidth / nativeAspect
        } else {
            scaledHeight = CGFloat(finalHeight)
            scaledWidth = scaledHeight * nativeAspect
        }

        let scale = scaledWidth / CGFloat(nativeWidth)

        let scaled = image.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": scale,
            "inputAspectRatio": 1.0
        ])

        let xOffset = (CGFloat(finalWidth) - scaledWidth) / 2
        let yOffset = (CGFloat(finalHeight) - scaledHeight) / 2
        let centered = scaled.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))

        let targetBackground = CIImage(color: CIColor.black)
            .cropped(to: CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))

        return centered.composited(over: targetBackground)
    }
}
