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
        guard let compressed = Data(base64Encoded: s.replacingOccurrences(of: "\n", with: "")) else {
            return []
        }

        var output = [UInt8](repeating: 0, count: 101 * 256)
        let outputCount = output.count
        let count = compressed.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!,
                    outputCount,
                    src.bindMemory(to: UInt8.self).baseAddress!,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        return Array(output.prefix(count))
    }()

    private func applyMeituBrightness(_ image: UIImage, _ value: Double) -> UIImage? {
        guard let cg = image.cgImage else { return nil }

        let width = cg.width
        let height = cg.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let v = max(-50.0, min(50.0, value))
        let raw = Int(v.rounded())
        let index = (raw + 50) * 256

        guard Self.brightnessData.count >= index + 256 else {
            return image
        }

        // byteOrder32Big + premultipliedFirst 的实际通道映射为:
        // [i]   -> Alpha
        // [i+1] -> Red
        // [i+2] -> Green
        // [i+3] -> Blue
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i + 1] = Self.brightnessData[index + Int(pixels[i + 1])]
            pixels[i + 2] = Self.brightnessData[index + Int(pixels[i + 2])]
            pixels[i + 3] = Self.brightnessData[index + Int(pixels[i + 3])]
        }

        guard let result = ctx.makeImage() else { return nil }

        return UIImage(
            cgImage: result,
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
            guard let result = applyMeituBrightness(output, brightness) else {
                return nil
            }
            output = result
        }

        guard let input = CIImage(image: output) else { return nil }
        var ciOutput = input

        if abs(contrast) > 0.001 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciOutput, forKey: kCIInputImageKey)
                filter.setValue(Float(1.0 + contrast / 50.0 * 0.5), forKey: "inputContrast")
                if let result = filter.outputImage {
                    ciOutput = result
                }
            }
        }

        if sharpness > 0.001 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(ciOutput, forKey: kCIInputImageKey)
                filter.setValue(1.0, forKey: "inputRadius")
                filter.setValue(Float(sharpness / 50.0 * 0.8), forKey: "inputSharpness")
                if let result = filter.outputImage {
                    ciOutput = result
                }
            }
        }

        guard let cgImage = context.createCGImage(ciOutput, from: ciOutput.extent) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}
