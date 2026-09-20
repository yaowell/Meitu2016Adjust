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

        if brightness != 0 || contrast != 0 {
            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: CGFloat(c), y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: CGFloat(c), z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(c), w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(
                        x: CGFloat(0.5 - 0.5 * c + b),
                        y: CGFloat(0.5 - 0.5 * c + b),
                        z: CGFloat(0.5 - 0.5 * c + b),
                        w: 0
                    )
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