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

        if brightness < -0.001 {
            output = applyOldMeituBrightness(
                output,
                amount: min(1.0, -brightness / 50.0)
            )
        } else if brightness > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = Float(brightness / 50.0 * 0.55)
            filter.contrast = 1.0
            filter.saturation = 1.0

            if let result = filter.outputImage {
                output = result
            }
        }

        if abs(contrast) > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = 0
            filter.contrast = Float(1.0 + contrast / 50.0 * 0.65)
            filter.saturation = 1.0

            if let result = filter.outputImage {
                output = result
            }
        }

        if sharpness > 0.001 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.radius = 1.0
            filter.sharpness = Float(sharpness / 50.0 * 0.8)

            if let result = filter.outputImage {
                output = result
            }
        }

        guard let cgImage = context.createCGImage(
            output,
            from: output.extent
        ) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    // ========== 【重写这里：分通道亮度，R G压暗多，蓝色少压】 ==========
    private func applyOldMeituBrightness(
        _ image: CIImage,
        amount: Double
    ) -> CIImage {
        let size = 32
        var cube = [Float]()
        cube.reserveCapacity(size * size * size * 4)

        // 权重，和GLSL保持一致：R*1.15  G*1.10  B*0.45
        let rWeight: Double = 1.15
        let gWeight: Double = 1.10
        let bWeight: Double = 0.45
        let contrastBoost: Double = 1.08

        for b in 0..<size {
            let blue = Double(b) / Double(size - 1)
            for g in 0..<size {
                let green = Double(g) / Double(size - 1)
                for r in 0..<size {
                    let red = Double(r) / Double(size - 1)

                    // 分通道偏移
                    var rr = red - amount * rWeight
                    var gg = green - amount * gWeight
                    var bb = blue - amount * bWeight

                    // 小幅对比度拉升，防止压暗发灰
                    rr = (rr - 0.5) * contrastBoost + 0.5
                    gg = (gg - 0.5) * contrastBoost + 0.5
                    bb = (bb - 0.5) * contrastBoost + 0.5

                    // clamp 0~1
                    rr = max(0.0, min(1.0, rr))
                    gg = max(0.0, min(1.0, gg))
                    bb = max(0.0, min(1.0, bb))

                    cube.append(Float(rr))
                    cube.append(Float(gg))
                    cube.append(Float(bb))
                    cube.append(1.0)
                }
            }
        }

        let data = cube.withUnsafeBufferPointer {
            Data(buffer: $0)
        }

        let filter = CIFilter.colorCube()
        filter.inputImage = image
        filter.cubeDimension = Float(size)
        filter.cubeData = data

        return filter.outputImage ?? image
    }
}