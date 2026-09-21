import UIKit
import CoreImage
import Compression

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    private init() {}

    private static let brightnessData: [UInt8] = {
        let s = """
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
"""
        let compact = s.replacingOccurrences(of: "\n", with: "")
        guard let compressed = Data(base64Encoded: compact) else {
            return []
        }

        let capacity = 101 * 256
        var output = [UInt8](repeating: 0, count: capacity)

        let decoded = compressed.withUnsafeBytes { src -> Int in
            output.withUnsafeMutableBytes { dst -> Int in
                guard let srcBase = src.bindMemory(to: UInt8.self).baseAddress,
                      let dstBase = dst.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }

                return compression_decode_buffer(
                    dstBase,
                    capacity,
                    srcBase,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decoded == capacity else {
            return []
        }

        return output
    }()

    private func applyMeituBrightness(_ image: UIImage, _ value: Double) -> UIImage? {
        guard let cg = image.cgImage else {
            return nil
        }

        let v = max(-50.0, min(50.0, value))

        if abs(v) < 0.001 {
            return image
        }

        let raw = Int(v.rounded())
        let lutOffset = (raw + 50) * 256

        if Self.brightnessData.count >= lutOffset + 256 {
            return applyLUT(image, offset: lutOffset)
        }

        return applyFallbackBrightness(image, v)
    }

    private func applyLUT(_ image: UIImage, offset: Int) -> UIImage? {
        guard let cg = image.cgImage else {
            return nil
        }

        let width = cg.width
        let height = cg.height
        let bytesPerRow = width * 4

        var pixels = [UInt8](
            repeating: 0,
            count: height * bytesPerRow
        )

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:
                CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        ctx.draw(
            cg,
            in: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )

        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i + 1] = Self.brightnessData[offset + Int(pixels[i + 1])]
            pixels[i + 2] = Self.brightnessData[offset + Int(pixels[i + 2])]
            pixels[i + 3] = Self.brightnessData[offset + Int(pixels[i + 3])]
        }

        guard let result = ctx.makeImage() else {
            return nil
        }

        return UIImage(
            cgImage: result,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    private func applyFallbackBrightness(
        _ image: UIImage,
        _ value: Double
    ) -> UIImage? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIExposureAdjust") else {
            return nil
        }

        filter.setValue(input, forKey: kCIInputImageKey)

        let ev = Float(value / 50.0 * 1.5)
        filter.setValue(ev, forKey: kCIInputEVKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(
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

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        var output = image

        if abs(brightness) > 0.001 {
            guard let result = applyMeituBrightness(
                output,
                brightness
            ) else {
                return nil
            }

            output = result
        }

        guard let input = CIImage(image: output) else {
            return nil
        }

        var ciOutput = input

        if abs(contrast) > 0.001,
           let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(
                ciOutput,
                forKey: kCIInputImageKey
            )

            filter.setValue(
                Float(1.0 + contrast / 50.0 * 0.5),
                forKey: kCIInputContrastKey
            )

            if let result = filter.outputImage {
                ciOutput = result
            }
        }

        if sharpness > 0.001,
           let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(
                ciOutput,
                forKey: kCIInputImageKey
            )

            filter.setValue(
                Float(sharpness / 50.0 * 0.8),
                forKey: kCIInputSharpnessKey
            )

            filter.setValue(
                1.0,
                forKey: kCIInputRadiusKey
            )

            if let result = filter.outputImage {
                ciOutput = result
            }
        }

        guard let cgImage = context.createCGImage(
            ciOutput,
            from: ciOutput.extent
        ) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    func processAsync(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double,
        completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.process(
                image,
                brightness: brightness,
                contrast: contrast,
                sharpness: sharpness
            )

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}