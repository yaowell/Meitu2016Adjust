import UIKit
import Foundation
import Compression

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private static let brightnessCompressed = """
    eNq91AVbFGEUhmHsAOxu7G7F7g7sbsXuVuxWsBuwE2zs7u7uIFTYInd3NkDdb2Zg6sx8M4vLT7iv5z3HKVXqNGnTpc+QMVNmZ2cX1yxZs2XPkTNX7jx58+UvULBQ4SJFi7m5FS9RslTpMmXLla9QsVLlKlWrVa9Rs1Ztd/c6devVb9CwUeMmTZs1b9GyVes2bdu179DRw6NT5y5du3Xv0bNX7z59+/UfMHDQ4CFDh3l6Dh8xctToMWPHjZ8wcdLkKVOnTZ8xc9ZsL685c+fNX7Bw0eIlS5ctX7FylbePz+o1a9et37Bx0+YtW7dt9/X189+xc9fuPXv37T9w8NDhgIDAI0ePHT9x8lTQ6TNnz52/cPHS5StXr12/cfPW7Tt3791/8PDR4ydPnz1/8fLV6zdv3334+Onzl6/fvgeHhIb9/BUeoVJrdZFRMbFxBqPJbIlP+OvE8ru4gn6KL/AzfK6fw2f8Aj7l5/O9MfxARfz3NP9HMOL/DlepNdrIqOiYOL2BMJmt8X94fhtfzJ/IB/xy8ifxufm5fJSfy/fj8216e/ghJD9CpaHz642EyQL6EV/Kz+ZDfogP5RfwqfXz+P5CPqlXNH4bP5TiqzU6lD9WbzASZnE/xcf7IT4mP8hnjp/Pt+khPksP8On4bH4YzdfqEJ+av8WaIOmXe/7Y/BAfPH6Ij/QSfPHtQ/XR+qMR30iQ70++35H5cXy+Xj6fjs/hk/nR97c6wp8CfKXxIT7hKL/j+fL1Unyl/v+cXwk/2fG5fCY/xp9S+SX4mO0DenD7DJ/OT89fxC9z/jLzy1o/yIdPX058mE+vn8ov4secP27+mPwSxy+Hr2D7Qj5r/WR+dP48vz3nL55ffP3g8eP4yk4/iU/fPnX85PpRftAPvz94/kryw+sX/D5JflCy+MzxJ+an3h/bD71/4PyB+UP5gfUDx899/RKvz04+9fmZ46fzs/z/AGIj/go=
    """

    private static let contrastCompressed = """
    eNpjYGRiZmFlY+fg5OLm4eXjFxAUEhYRFROXkJSSlpGVk1dQVFJWUVVT19DU0tbR1dM3MDQyNjE1M7ewtLK2sbWzd3B0cnZxdXP38PTy9vH18w8IDAoOCQ0Lj4iMio6JjYtPSExKTklNS8/IzMrOyc3LLygsKi4pLSuvqKyqrqmtq29obGpuaW1r7+js6u7p7eufMHHS5ClTp02fMXPW7Dlz581fsHDR4iVLly1fsXLV6jVr163fsHHT5i1bt23fsXPX7j179+0/cPDQ4SNHjx0/cfLU6TNnz52/cPHS5StXr12/cfPW7Tt3791/8PDR4ydPnz1/8fLV6zdv373/8PHT5y9fv33/8fPX7z9///1nGPX/qP9H/T/qf2z+p1IAkOt/KnmfZP/TLAEQ53+aRT8R/qd9BsDvf9onfzT/AwDAyfwu
    """

    private static let brightnessLUT = inflate(
        brightnessCompressed,
        outputSize: 4096
    )

    private static let contrastLUT = inflate(
        contrastCompressed,
        outputSize: 2048
    )

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }

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
        let value = max(
            -50.0,
            min(50.0, value)
        )

        if value == 0 {
            return
        }

        let internalValue = value / 10.0

        let index = Int(
            (internalValue * 1.5 + 0.5)
                .rounded(.towardZero)
        )

        let lutIndex = max(
            -7,
            min(8, index)
        )

        let tableIndex = lutIndex + 7
        let base = tableIndex * 256

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
        let value = max(
            -50.0,
            min(50.0, value)
        )

        if value == 0 {
            return
        }

        let internalValue = value / 10.0

        let indexValue: Double

        if internalValue < 0 {
            indexValue =
                internalValue * 0.5 + 0.5
        } else {
            indexValue = internalValue
        }

        let index = Int(
            indexValue.rounded(.towardZero)
        )

        let lutIndex = max(
            -2,
            min(5, index)
        )

        if lutIndex == 0 {
            return
        }

        let tableIndex = lutIndex + 2
        let base = tableIndex * 256

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
        let s = Float(value / 50.0)

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

    private static func inflate(
        _ base64: String,
        outputSize: Int
    ) -> [UInt8] {
        guard let compressed = Data(
            base64Encoded: base64,
            options: .ignoreUnknownCharacters
        ) else {
            return []
        }

        var output = [UInt8](
            repeating: 0,
            count: outputSize
        )

        let decoded = output.withUnsafeMutableBytes {
            destination in
            compressed.withUnsafeBytes {
                source in
                compression_decode_buffer(
                    destination
                        .bindMemory(to: UInt8.self)
                        .baseAddress!,
                    outputSize,
                    source
                        .bindMemory(to: UInt8.self)
                        .baseAddress!,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if decoded != outputSize {
            return []
        }

        return output
    }
}