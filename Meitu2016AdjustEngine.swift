import UIKit
import CoreImage

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()
    private let context = CIContext()

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard var ciImage = CIImage(image: image) else {
            return nil
        }

        // GPUImageBrightnessFilter:
        // textureColor.rgb + brightness
        if brightness != 0 {
            let b = Float(brightness / 50.0)

            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(
                        x: CGFloat(b),
                        y: CGFloat(b),
                        z: CGFloat(b),
                        w: 0
                    )
                ]
            )
        }

        // GPUImageContrastFilter:
        // (textureColor.rgb - 0.5) * contrast + 0.5
        if contrast != 0 {
            let c = Float(1.0 + contrast / 50.0)
            let bias = 0.5 - 0.5 * c

            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: CGFloat(c), y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: CGFloat(c), z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(c), w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(
                        x: CGFloat(bias),
                        y: CGFloat(bias),
                        z: CGFloat(bias),
                        w: 0
                    )
                ]
            )
        }

        // GPUImage-style sharpening.
        // Keep this separate from brightness/contrast so the three
        // controls do not alter each other's parameters.
        if sharpness != 0 {
            let s = max(-1.0, min(1.0, Float(sharpness / 50.0)))

            let radius: CGFloat = 1.0
            let blurred = ciImage.applyingFilter(
                "CIGaussianBlur",
                parameters: [
                    kCIInputRadiusKey: radius
                ]
            ).cropped(to: ciImage.extent)

            let sharpened = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ]
            )

            let amount = CGFloat(s)

            ciImage = sharpened.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(
                        x: 1.0 + amount,
                        y: 0,
                        z: 0,
                        w: 0
                    ),
                    "inputGVector": CIVector(
                        x: 0,
                        y: 1.0 + amount,
                        z: 0,
                        w: 0
                    ),
                    "inputBVector": CIVector(
                        x: 0,
                        y: 0,
                        z: 1.0 + amount,
                        w: 0
                    ),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(
                        x: -amount * 0.5,
                        y: -amount * 0.5,
                        z: -amount * 0.5,
                        w: 0
                    )
                ]
            )

            _ = blurred
        }

        guard let output = context.createCGImage(
            ciImage,
            from: ciImage.extent
        ) else {
            return nil
        }

        return UIImage(
            cgImage: output,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}