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

    private func applyOldMeituBrightness(
        _ image: CIImage,
        amount: Double
    ) -> CIImage {
        let size = 32
        var cube = [Float]()
        cube.reserveCapacity(size * size * size * 4)

        for b in 0..<size {
            let blue = Double(b) / Double(size - 1)

            for g in 0..<size {
                let green = Double(g) / Double(size - 1)

                for r in 0..<size {
                    let red = Double(r) / Double(size - 1)

                    let y =
                        0.2126 * red +
                        0.7152 * green +
                        0.0722 * blue

                    let shadow = max(
                        0.0,
                        min(1.0, 1.0 - y / 0.55)
                    )

                    let highlight = max(
                        0.0,
                        min(1.0, (y - 0.25) / 0.75)
                    )

                    let darkScale =
                        1.0 -
                        amount * (
                            0.28 +
                            0.42 * pow(highlight, 0.72)
                        )

                    var rr = red * darkScale
                    var gg = green * darkScale
                    var bb = blue * darkScale

                    let blueDominance =
                        max(
                            0.0,
                            blue - max(red, green) * 0.72
                        )

                    let blueBoost =
                        amount *
                        blueDominance *
                        (0.22 + 0.42 * highlight)

                    bb += blueBoost

                    let warmPreserve =
                        max(
                            0.0,
                            red - blue * 0.72
                        )

                    let warmBoost =
                        amount *
                        warmPreserve *
                        0.10 *
                        (0.35 + shadow)

                    rr += warmBoost

                    let saturation =
                        1.0 +
                        amount * 0.12

                    let mid =
                        0.299 * rr +
                        0.587 * gg +
                        0.114 * bb

                    rr = mid + (rr - mid) * saturation
                    gg = mid + (gg - mid) * saturation
                    bb = mid + (bb - mid) * saturation

                    let shadowLift =
                        amount *
                        0.035 *
                        shadow

                    rr += shadowLift
                    gg += shadowLift
                    bb += shadowLift

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