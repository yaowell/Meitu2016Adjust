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

        let b = Float(brightness / 50.0)
        let c = Float(1.0 + contrast / 50.0)

        if brightness != 0 {
            ciImage = ciImage.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputBrightnessKey: b
                ]
            )
        }

        if contrast != 0 {
            ciImage = ciImage.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputContrastKey: c
                ]
            )
        }

        if sharpness != 0 {
            let s = Float(sharpness / 50.0)

            ciImage = ciImage.applyingFilter(
                "CISharpenLuminance",
                parameters: [
                    kCIInputSharpnessKey: s
                ]
            )
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