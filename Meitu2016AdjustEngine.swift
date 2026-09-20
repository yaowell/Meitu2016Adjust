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

        if brightness != 0 {
            let b = CGFloat(brightness / 50.0)

            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: b, y: b, z: b, w: 0)
                ]
            )
        }

        if contrast != 0 {
            let c = CGFloat(1.0 + contrast / 50.0)
            let bias = CGFloat(0.5 - 0.5 * c)

            ciImage = ciImage.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: c, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: c, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: c, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0)
                ]
            )
        }

        if sharpness != 0 {
            let s = CGFloat(sharpness / 50.0)

            let a = -s * 0.25
            let center = 1.0 + s

            let weights = CIVector(
                x: 0,
                y: a,
                z: 0,
                w: a
            )

            let extraWeights = [
                center,
                a,
                0,
                a,
                0
            ]

            var values: [CGFloat] = [
                weights.value(at: 0),
                weights.value(at: 1),
                weights.value(at: 2),
                weights.value(at: 3)
            ]

            values.append(contentsOf: extraWeights)

            if values.count == 9 {
                ciImage = ciImage.applyingFilter(
                    "CIConvolution3X3",
                    parameters: [
                        "inputWeights": CIVector(values: values),
                        "inputBias": 0
                    ]
                )
            }
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