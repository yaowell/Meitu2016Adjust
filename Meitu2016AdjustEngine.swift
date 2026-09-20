import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    private init() {}

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard let input = CIImage(image: image) else {
            return nil
        }

        var output = input

        let b = max(-1.0, min(1.0, brightness / 50.0))
        let c = max(-1.0, min(1.0, contrast / 50.0))
        let s = max(-1.0, min(1.0, sharpness / 50.0))

        if b < 0 {
            output = oldMeituDarken(output, amount: -b)
        } else if b > 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = Float(b * 0.65)
            filter.contrast = 1.0
            filter.saturation = 1.0
            if let result = filter.outputImage {
                output = result
            }
        }

        if abs(c) > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = 0
            filter.contrast = Float(1.0 + c * 0.8)
            filter.saturation = 1.0
            if let result = filter.outputImage {
                output = result
            }
        }

        if abs(s) > 0.001 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.sharpness = Float(s * 0.8)
            filter.radius = 1.0
            if let result = filter.outputImage {
                output = result
            }
        }

        let extent = output.extent

        guard let cgImage = context.createCGImage(output, from: extent) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    private func oldMeituDarken(
        _ image: CIImage,
        amount: Double
    ) -> CIImage {
        let a = max(0.0, min(1.0, amount))

        let filter = CIFilter.colorControls()
        filter.inputImage = image

        let brightness = -0.42 * a
        let contrast = 1.0 + 0.28 * a
        let saturation = 1.0 + 0.18 * a

        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        filter.saturation = Float(saturation)

        guard let result = filter.outputImage else {
            return image
        }

        return result
    }
}