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

        let b = CGFloat(brightness / 50.0)
        let c = CGFloat(1.0 + contrast / 50.0)

        if brightness != 0 || contrast != 0 {
            let bias = 0.5 - 0.5 * c + b

            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: c, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: c, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: c, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(
                        x: bias,
                        y: bias,
                        z: bias,
                        w: 0
                    )
                ]
            )
        }

        if sharpness != 0 {
            let s = CGFloat(sharpness / 50.0)
            let a = -s / 4.0
            let center = 1.0 + s

            var weights: [CGFloat] = []
            weights.append(0)
            weights.append(a)
            weights.append(0)
            weights.append(a)
            weights.append(center)
            weights.append(a)
            weights.append(0)
            weights.append(a)
            weights.append(0)

            let vector = CIVector(
                values: weights,
                count: weights.count
            )

            ciImage = ciImage.applyingFilter(
                "CIConvolution3X3",
                parameters: [
                    "inputWeights": vector,
                    "inputBias": 0
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