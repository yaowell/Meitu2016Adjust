import UIKit
import CoreGraphics
import Compression

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private static let compressedLUT = """
eNrt1vVDE2EcBnDsAOxu7G7F7g7sbsXuRLFbwW7ATrCxu7u7g1AXMGBjHeouttvdvnf33oKf+BM+9zzP916PNGnTpc+QMVPmLFk9Pb28s2XPkTNX7jx58+UvULBQ4SJFixUv4eNTslTpMmXLla9QsVLlKlWrVa9Rs1btOnV9fevVb9CwUeMmTZs1b9GyVes2bdu179CxU2c/vy5du3Xv0bNX7z59+/UfMHDQ4CFDhw0f4e8/ctToMWPHjZ8wcdLkKVOnTZ8xc1bA7DmBgXPnzV+wcNHiJUuXLV+xctXqoODgNWvXrd+wcdPmLVu3bd8REhIatnPX7j179+0/cPDQ4SPh4RFHjx0/cfLU6cgzZ8+dv3Dx0uUrV69dv3Hz1u07d+/df/Dw0eMnT589f/Hy1es3b9+9//jp85ev377/iIqOif31WySWSONlCYlyRbJKrdXpjaZ/HjZ+L2/QT/Dt/BSf7qfxKb8dn/Az+UE8/AhB/A8k/2cUxv8jkkjj4hMSk+TJSpVGqzMY/zL8Zj6b38IH/CjxW/n0+Ol8LH46P5TJN+sd4UfjfLEkjoxfqdZo9aAf43P5bfmQH+JD8dvxifYz+GH2fFwvqPxmfgzBl8bJsPgVSpVao2P3E3x+P8TniR/kU+Nn8s16iG+jB/hk+Lb8WJIfL8P4RP31BhOnH3X+vPFDfHD8EB/Tc/DZuw+lj7U/CeOrNfj5Q/e7M34+PlOPzifDp/Hx+LHrb3CH3/169OjZ9RqtUL9r2x8ghO9U8zE9nW9pv8HI40+p+Dn4PMMH9ABfJKb4ZPyE38TiR6w/YvxI7Qf58NlHCR/mk+0n4mfx88yfr/488XOMH4UvoPv2fJv24/Fj82f4HZk/e/zs7QfHz8cXNn0rn9w+MX68/Vj8oB8+f3D9hcQPt9/u9nHyI53iU+O3xE+cP1s/dP6B+QP1h+IH2g+Mn376OU6fg3zi8lPjJ+MH/fj+nf398///uB8ASC8AR/6B1l+gXEH9AJ27/8L9aA8gt/lpDyCU94+L/I4+AF3khx+Abnr/psDz36n6p/pT/al+RL+LPoCjfhfxOf3/AbD8esY=
"""

    private static let lutData: [UInt8]? = {
        guard let compressed = Data(base64Encoded: compressedLUT) else {
            return nil
        }

        var output = [UInt8](repeating: 0, count: 5888)
        let outputSize = output.count
        let compressedSize = compressed.count

        let count = compressed.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!,
                    outputSize,
                    src.bindMemory(to: UInt8.self).baseAddress!,
                    compressedSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard count == outputSize else {
            return nil
        }

        return output
    }()

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard let cg = image.cgImage else {
            return nil
        }

        let width = cg.width
        let height = cg.height
        let rowBytes = width * 4

        var pixels = [UInt8](
            repeating: 0,
            count: rowBytes * height
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: colorSpace,
            bitmapInfo:
                CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.draw(
            cg,
            in: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )

        applyOriginalBrightness(
            &pixels,
            value: brightness
        )

        applyOriginalContrast(
            &pixels,
            value: contrast
        )

        if sharpness != 0 {
            applySharpen(
                &pixels,
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

    private func applyOriginalBrightness(
        _ pixels: inout [UInt8],
        value: Double
    ) {
        guard let lut = Self.lutData else {
            return
        }

        let internalValue = Float(
            max(-50.0, min(50.0, value))
        ) * 0.1

        let index = Int(
            internalValue * 1.5 + 0.5
        )

        guard index != 0,
              index >= -7,
              index <= 8 else {
            return
        }

        let tableIndex: Int

        if index < 0 {
            tableIndex = index + 7
        } else {
            tableIndex = index + 6
        }

        applyLUT(
            &pixels,
            lut: lut,
            offset: tableIndex * 256
        )
    }

    private func applyOriginalContrast(
        _ pixels: inout [UInt8],
        value: Double
    ) {
        guard let lut = Self.lutData else {
            return
        }

        let internalValue = Float(
            max(-50.0, min(50.0, value))
        ) * 0.1

        let index: Int

        if internalValue < 0 {
            index = Int(internalValue)
        } else {
            index = Int(
                internalValue * 0.5 + 0.5
            )
        }

        guard index != 0,
              index >= -5,
              index <= 3 else {
            return
        }

        let tableIndex: Int

        if index < 0 {
            tableIndex = 15 + index + 5
        } else {
            tableIndex = 15 + index + 4
        }

        applyLUT(
            &pixels,
            lut: lut,
            offset: tableIndex * 256
        )
    }

    private func applyLUT(
        _ pixels: inout [UInt8],
        lut: [UInt8],
        offset: Int
    ) {
        guard offset >= 0,
              offset + 255 < lut.count else {
            return
        }

        var i = 1

        while i + 2 < pixels.count {
            pixels[i] =
                lut[offset + Int(pixels[i])]

            pixels[i + 1] =
                lut[offset + Int(pixels[i + 1])]

            pixels[i + 2] =
                lut[offset + Int(pixels[i + 2])]

            i += 4
        }
    }

    private func applySharpen(
        _ pixels: inout [UInt8],
        width: Int,
        height: Int,
        value: Double
    ) {
        let s = Float(value / 50.0)

        guard s != 0 else {
            return
        }

        let source = pixels
        let center = 1.0 + 4.0 * s

        for y in 0..<height {
            let topY = max(0, y - 1)
            let bottomY = min(height - 1, y + 1)

            for x in 0..<width {
                let leftX = max(0, x - 1)
                let rightX = min(width - 1, x + 1)

                let centerIndex = (y * width + x) * 4
                let leftIndex = (y * width + leftX) * 4
                let rightIndex = (y * width + rightX) * 4
                let topIndex = (topY * width + x) * 4
                let bottomIndex = (bottomY * width + x) * 4

                for channel in 1...3 {
                    let result =
                        Float(source[centerIndex + channel]) * center
                        -
                        Float(
                            source[leftIndex + channel] +
                            source[rightIndex + channel] +
                            source[topIndex + channel] +
                            source[bottomIndex + channel]
                        ) * s

                    pixels[centerIndex + channel] =
                        UInt8(
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