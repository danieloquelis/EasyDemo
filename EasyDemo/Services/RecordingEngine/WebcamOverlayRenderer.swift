import Foundation
import CoreImage
import CoreGraphics

final class WebcamOverlayRenderer {
    private let maskGenerator = ShapeMaskGenerator()
    private var cachedMask: CIImage?
    private var cachedMaskSize: CGSize = .zero
    private var cachedMaskShape: WebcamConfiguration.Shape?

    func createOverlay(
        webcamFrame: CIImage,
        configuration: WebcamConfiguration,
        canvasSize: CGSize,
        scaleFactor: CGFloat
    ) -> CIImage {
        let size = configuration.size * scaleFactor
        let padding: CGFloat = UIConstants.Padding.large * scaleFactor
        let targetSize = CGSize(width: size, height: size)

        let scaledWebcam = scaleAndCropWebcam(webcamFrame, to: targetSize)
        let maskedWebcam = applyMask(to: scaledWebcam, shape: configuration.shape, size: targetSize, scaleFactor: scaleFactor)
        let webcamWithShadow = addShadow(to: maskedWebcam, size: targetSize, scaleFactor: scaleFactor)

        let position = configuration.position.offset(
            in: canvasSize,
            webcamSize: size,
            padding: padding
        )

        let flippedY = canvasSize.height - position.y - size

        return webcamWithShadow.transformed(
            by: CGAffineTransform(translationX: position.x, y: flippedY)
        )
    }

    private func scaleAndCropWebcam(_ webcamFrame: CIImage, to targetSize: CGSize) -> CIImage {
        let webcamAspect = webcamFrame.extent.width / webcamFrame.extent.height
        let targetAspect = targetSize.width / targetSize.height

        let scale: CGFloat
        let cropRect: CGRect

        if webcamAspect > targetAspect {
            scale = targetSize.height / webcamFrame.extent.height
            let scaledWidth = webcamFrame.extent.width * scale
            let offsetX = (scaledWidth - targetSize.width) / 2
            cropRect = CGRect(x: offsetX, y: 0, width: targetSize.width, height: targetSize.height)
        } else {
            scale = targetSize.width / webcamFrame.extent.width
            let scaledHeight = webcamFrame.extent.height * scale
            let offsetY = (scaledHeight - targetSize.height) / 2
            cropRect = CGRect(x: 0, y: offsetY, width: targetSize.width, height: targetSize.height)
        }

        return webcamFrame
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
    }

    private func applyMask(to image: CIImage, shape: WebcamConfiguration.Shape, size: CGSize, scaleFactor: CGFloat) -> CIImage {
        let mask: CIImage?

        if let cachedMask = cachedMask,
           cachedMaskSize == size,
           cachedMaskShape == shape {
            mask = cachedMask
        } else {
            mask = maskGenerator.createMask(for: shape, size: size, scaleFactor: scaleFactor)
            cachedMask = mask
            cachedMaskSize = size
            cachedMaskShape = shape
        }

        guard let validMask = mask else { return image }

        let maskRect = CGRect(origin: .zero, size: size)
        let croppedImage = image.cropped(to: maskRect)
        let imageAtOrigin = croppedImage.transformed(
            by: CGAffineTransform(translationX: -croppedImage.extent.origin.x, y: -croppedImage.extent.origin.y)
        )

        return imageAtOrigin.applyingFilter("CIBlendWithAlphaMask", parameters: [
            "inputMaskImage": validMask
        ])
    }

    private func addShadow(to image: CIImage, size: CGSize, scaleFactor: CGFloat) -> CIImage {
        let maskRect = CGRect(origin: .zero, size: size)
        let shadowRadius = ColorPalette.Shadow.radius * scaleFactor
        let shadowOffset = CGSize(width: 0, height: -10 * scaleFactor)
        let shadowOpacity: CGFloat = 0.6

        guard let mask = cachedMask else { return image }

        let shadowMask = CIImage(color: CIColor.black)
            .cropped(to: maskRect)
            .applyingFilter("CIBlendWithAlphaMask", parameters: ["inputMaskImage": mask])

        let shadow = shadowMask
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": shadowRadius])
            .transformed(by: CGAffineTransform(translationX: shadowOffset.width, y: shadowOffset.height))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: shadowOpacity)
            ])

        return image.composited(over: shadow)
    }
}
