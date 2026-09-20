import UIKit
import Foundation

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private static let brightnessBase64 = """
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
"""

    private static let contrastBase64 = """
AAECAwQFBgcICQoLDA0OEBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6Oj5CRkpOUlZaXmJmam5ydnp+goaKjpKWmp6ipqqusra6vsLGys7S1tre4ubq7vL2+v8DBwsPExcbHyMnKy8zNzs/Q0dLT1NXW19jZ2tvc3d7f4OHi4+Tl5ufo6err7O3u7/Hy8/T19vf4+fr7/P3+/wABAgMEBQYHCAkKCwwNDg8QERITFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKSktMTU5PUFFSU1RVVldYWVpbXF1eX2BhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ent8fX5/gIGCg4SFhoeIiYqLjI2Oj5CRkpOUlZaXmJmam5ydnp+goaKjpKWmp6ipqqusra6vsLGys7S1tre4ubq7vL2+v8DBwsPExcbHyMnKy8zNzs/Q0dLT1NXW19jZ2tvc3d7f4OHi4+Tl5ufo6err7O3u7/Hy8/T19vf4+fr7/P3+/wABAgMEBQYHCAkKCwwNDg8QERITFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKSktMTU5PUFFSU1RVVldYWVpbXF1eX2BhYmNkZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+f4CBgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpubnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbY2drb3N3e3+Dh4uPk5ebn6Onq6+zt7u/w8fLz9PX29/j5+vv8/f7/AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vLzAxMjM0NTY3ODk6Ozw9Pj9AQUJDREVGR0hJSktMTU5OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+f4CBgoOFhoeIiYqLjI2Oj5CRkpOUlZaXmJmam5ydnp+goaKjpKWmp6ipqqusra6vsLGys7S1tre4ubq7vL2+v8DBwsPExcbHyMnKy8zNzs/Q0dLT1NXW19jZ2tvc3d7f4OHi4+Tl5ufo6err7O3u7/Dx8vP09fb3+Pn6+/z9/v8AAQIDBAUGBwgJCgsMDg8QERITFBUWFxgZGhscHB0eHyAhIiMkJSYnKCkqKywtLi8wMTM0NTY3ODk6Ozw9Pj9AQUJDRUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6Cio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc7P0NHS09jZ2tvb3N3e3+Dh4uPk5ebn6Onq6+zt7u/w8fLz9PX29/j5+vv8/f7/
"""

    private static let brightnessLUT = Data(base64Encoded: brightnessBase64)!.map { $0 }
    private static let contrastLUT = Data(base64Encoded: contrastBase64)!.map { $0 }

    func process(_ image: UIImage, brightness: Double, contrast: Double, sharpness: Double) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4

        var data = [UInt8](
            repeating: 0,
            count: bytesPerRow * height
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.draw(
            cgImage,
            in: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )

        applyBrightness(
            &data,
            value: brightness
        )

        applyContrast(
            &data,
            value: contrast
        )

        if sharpness != 0 {
            applySharpen(
                &data,
                width: width,
                height: height,
                value: sharpness
            )
        }

        guard let output = context.makeImage() else {
            return nil
        }

        return UIImage(
            cgImage: output,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    private func applyBrightness(
        _ data: inout [UInt8],
        value: Double
    ) {
        let v = max(
            -50.0,
            min(50.0, value)
        )

        if v == 0 {
            return
        }

        let internalValue = v / 10.0

        let index = Int(
            (internalValue * 1.5 + 0.5)
                .rounded(.towardZero)
        )

        if index == 0 {
            return
        }

        let table = index < 0
            ? index + 7
            : index + 6

        let base = table * 256

        guard
            table >= 0,
            table < 15,
            base + 255 < Self.brightnessLUT.count
        else {
            return
        }

        for i in stride(
            from: 0,
            to: data.count,
            by: 4
        ) {
            data[i + 1] =
                Self.brightnessLUT[
                    base + Int(data[i + 1])
                ]

            data[i + 2] =
                Self.brightnessLUT[
                    base + Int(data[i + 2])
                ]

            data[i + 3] =
                Self.brightnessLUT[
                    base + Int(data[i + 3])
                ]
        }
    }

    private func applyContrast(
        _ data: inout [UInt8],
        value: Double
    ) {
        let v = max(
            -50.0,
            min(50.0, value)
        )

        if v == 0 {
            return
        }

        let internalValue = v / 10.0

        let index: Int

        if internalValue < 0 {
            index = Int(
                internalValue.rounded(.towardZero)
            )
        } else {
            index = Int(
                (internalValue * 0.5 + 0.5)
                    .rounded(.towardZero)
            )
        }

        if index == 0 ||
            index == -1 ||
            index == 1 ||
            index == 2 {
            return
        }

        let table: Int

        switch index {
        case -5:
            table = 0
        case -4:
            table = 1
        case -3:
            table = 2
        case -2:
            table = 3
        case 3:
            table = 4
        case 4:
            table = 5
        case 5:
            table = 6
        default:
            return
        }

        let base = table * 256

        guard
            base + 255 < Self.contrastLUT.count
        else {
            return
        }

        for i in stride(
            from: 0,
            to: data.count,
            by: 4
        ) {
            data[i + 1] =
                Self.contrastLUT[
                    base + Int(data[i + 1])
                ]

            data[i + 2] =
                Self.contrastLUT[
                    base + Int(data[i + 2])
                ]

            data[i + 3] =
                Self.contrastLUT[
                    base + Int(data[i + 3])
                ]
        }
    }

    private func applySharpen(
        _ data: inout [UInt8],
        width: Int,
        height: Int,
        value: Double
    ) {
        let s = Float(
            value / 50.0
        )

        if s == 0 {
            return
        }

        let source = data
        let center = 1.0 + 4.0 * s

        for y in 0..<height {
            let topY = max(
                0,
                y - 1
            )

            let bottomY = min(
                height - 1,
                y + 1
            )

            for x in 0..<width {
                let leftX = max(
                    0,
                    x - 1
                )

                let rightX = min(
                    width - 1,
                    x + 1
                )

                let p = (y * width + x) * 4
                let l = (y * width + leftX) * 4
                let r = (y * width + rightX) * 4
                let t = (topY * width + x) * 4
                let b = (bottomY * width + x) * 4

                for channel in 1...3 {
                    let result =
                        Float(source[p + channel]) * center
                        - Float(source[l + channel]) * s
                        - Float(source[r + channel]) * s
                        - Float(source[t + channel]) * s
                        - Float(source[b + channel]) * s

                    data[p + channel] = UInt8(
                        max(
                            0,
                            min(
                                255,
                                Int(result.rounded())
                            )
                        )
                    )
                }
            }
        }
    }
}