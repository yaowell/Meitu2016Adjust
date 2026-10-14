import UIKit
import CoreImage

enum BrightnessAlgorithm: String, CaseIterable, Identifiable {
    case original = "原版"
    case rgb = "RGB偏移"
    case exposure = "曝光"
    case gamma = "Gamma"
    case highlightShadow = "高光阴影"
    case curve = "自定义曲线"

    var id: String { rawValue }
}

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
        sharpness: Double,
        algorithm: BrightnessAlgorithm = .original
    ) -> UIImage? {
        guard let input = CIImage(image: image) else {
            return nil
        }

        var output = input
        let b = max(-50, min(50, brightness)) / 50.0

        if abs(b) > 0.001 {
            switch algorithm {
            case .original:
                if b < 0 {
                    if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
                        filter.setValue(output, forKey: kCIInputImageKey)
                        filter.setValue(
                            1.0 + b * 0.8,
                            forKey: "inputHighlightAmount"
                        )
                        filter.setValue(
                            0.0,
                            forKey: "inputShadowAmount"
                        )

                        if let result = filter.outputImage {
                            output = result
                        }
                    }

                    if let filter = CIFilter(name: "CIExposureAdjust") {
                        filter.setValue(output, forKey: kCIInputImageKey)
                        filter.setValue(
                            Float(b * 0.4),
                            forKey: "inputEV"
                        )

                        if let result = filter.outputImage {
                            output = result
                        }
                    }
                } else if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(
                        Float(b * 0.35),
                        forKey: "inputBrightness"
                    )

                    if let result = filter.outputImage {
                        output = result
                    }
                }

            case .rgb:
                if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(
                        Float(b * 0.5),
                        forKey: "inputBrightness"
                    )

                    if let result = filter.outputImage {
                        output = result
                    }
                }

            case .exposure:
                if let filter = CIFilter(name: "CIExposureAdjust") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(
                        Float(b * 2.0),
                        forKey: "inputEV"
                    )

                    if let result = filter.outputImage {
                        output = result
                    }
                }

            case .gamma:
                if let filter = CIFilter(name: "CIGammaAdjust") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(
                        Float(pow(2.0, -b * 1.5)),
                        forKey: "inputPower"
                    )

                    if let result = filter.outputImage {
                        output = result
                    }
                }

            case .highlightShadow:
                if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(
                        Float(1.0 - max(0.0, -b) * 0.8),
                        forKey: "inputHighlightAmount"
                    )
                    filter.setValue(
                        Float(max(0.0, b) * 1.5),
                        forKey: "inputShadowAmount"
                    )

                    if let result = filter.outputImage {
                        output = result
                    }
                }

            case .curve:
                if let filter = CIFilter(name: "CIToneCurve") {
                    let amount = b * 0.25

                    func point(_ x: Double) -> CIVector {
                        let y = max(
                            0.0,
                            min(1.0, x + amount * 4.0 * x * (1.0 - x))
                        )

                        return CIVector(x: x, y: y)
                    }

                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(point(0.0), forKey: "inputPoint0")
                    filter.setValue(point(0.25), forKey: "inputPoint1")
                    filter.setValue(point(0.5), forKey: "inputPoint2")
                    filter.setValue(point(0.75), forKey: "inputPoint3")
                    filter.setValue(point(1.0), forKey: "inputPoint4")

                    if let result = filter.outputImage {
                        output = result
                    }
                }
            }
        }

        if abs(contrast) > 0.001,
           let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(
                Float(1.0 + contrast / 50.0 * 0.5),
                forKey: "inputContrast"
            )

            if let result = filter.outputImage {
                output = result
            }
        }

        if sharpness > 0.001,
           let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(1.0, forKey: "inputRadius")
            filter.setValue(
                Float(min(50.0, sharpness) / 50.0 * 0.8),
                forKey: "inputSharpness"
            )

            if let result = filter.outputImage {
                output = result
            }
        }

        guard let cgImage = context.createCGImage(
            output,
            from: input.extent
        ) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}