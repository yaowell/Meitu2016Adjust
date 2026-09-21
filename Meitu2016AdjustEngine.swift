import UIKit
import CoreImage
import Compression

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    private init() {}

    // 解压美图 5.2.1 逆向出来的 101 * 256 亮度曲线 LUT
    private static let brightnessData: [UInt8] = {
        let s = """
eNq9nQXbXsURhotDcHf3IMFdgiQ4QYMHKyRYkJYipVSp00IFJziFYsWlpWgIGjRA0SKBhBBXpLI7MzuyO3vO+wXan/Bczz33zDnv+ZJvzDDDjDPNNPPMs8w662yzzz7HHN3mnHOuueeeZ55555tv/gUWWHDBhRZeeJFFF11sscWXWGLJpZZaeullll12ueWXX2HFFVdaaeVVVll1tdVWX737GmusudZaa6/dY5111l1vvfXX32DDDTfaeONNNtl0s80232KLLbfcauute26zzbbbbrf99r16995hxx132mnnXXbZdbfddt+9zx577LnXXnvvvc+++/bdb7/9DzjgwIMOOviQfv0OPeyww4848shvHnX00f0HHHPMsccdf8IJA0886eSTT/nWt0/9zmmnn37Gmd8963tnf/8HP/zRj39yzk9/9vNf/PJXvz73N+ed/7vf/+GPF1508SWXXT7oyquuvva6P93w55tuue0vd9x1z733//XBhx59/Iknn3nuhZdf/cdb//xwxOgJ0/7zDT//vJR/Icq/+OJLLBnzL7PMsstR/pVXXmXVmL979zXWjPl79Fhn3XVj/A023GijGH/TzTbfPMbfauuePSl+r9477BDj77zLrrtS/D2L+Idg/CNC/KNC/AEx/vEx/kkYP+T34//2vPND/AsuvPiSSy8bdMWVV19z3fU33HjTzbfedvudd99z3wN/+/vDjz4+5Klnhr4Y8r/t5+/Wbc65KP/888f6F1p4kUWo/iXd+rtT/UX8zSh+0f7O1H6fPjH9Xnvvs8++ffvut//+Bxx4IKY/FNOH9vv3j+mPi+lPhPTQfkjf3P6llw+64iod/64Y/8GHHgn1P/3c8y8Ne+2Nd94bPlLln8Xkn0fyW/yL+len+gv6sf0t3PYt/Cb+wRj/cBU/wj9wIMRH+M/oqP2rrrn2+kT/nXffez/W/8RTAf+Xhr3+5jvvDx85ZqLOP5vJ7+Ffqb8eH9vvmbeP7Pfx2G8bfWHfxo/pY/sXUPsB/hD/xhD/VohP9If6n33+xVfC+L/7/kefFPnncPIz/lj/snn9mv71DP2N7fvxW0b/1BTfax/iX3hRaP/yK8B9iX6SH+Z/JuD/ymtBfx/4+Vl/Gv+yfis/rr8hfta+w37z6Lexz+0T/EH9KX6i/7HBQ55+dugLLw97/Y2gv49HjZ342VfLn9Xv0h/ct912tv3pGP1i72X5z1ftx80X3BfovznQD+6Pu4/xf/nVMP7vxfyTnPzN+Af7dRC/vf2vMPot7Qv8FB/oh+kfPATsF/F/9/3hIz4dV+T3x79av09/tX0ffn/0j/FHvwn+sPli+3HzofoT/fc9EOp/BOsf+kLcfmX+bP1Z/E39K2T1N8bP28/NZ9nvcPTd+BdK+xH+FB8uH5Qf1I/4vx30N7KeX8bf4G/qN/IT+o376u0L/BS/X6ej39Z+3HzRfYH+24h+OH24/rD93nwn5h89bjLll/NP9Ffg79Uv9BfxBf6i/Rr7baOv2M/iX0Dtg/oi/EH9Jr6qP+If9ffJ6PGTP6/kp/EX+xP+Rf0iP0u/uK9on+An8U/H6PvtX4Ltx80X3RcOH6I/yu+hRx6L9RP+Yfzd/LT+SH80/oR/tJ+tn+hvik/wu+0r9vXaG+CNfgfsS/sEv40f6I/1DwX7h/EP+hs1ZoKT3+qvxF/VT7uP5KdWn3Wfap/Up+D3Rv+4/OCn+Er8ef6Ldfvx7A3uQ/pRfo88NjjVP+w1GH/IP0XlV+tfjb+yf7RfrH8lqZ/or8fP2qe9p8Tf1dFvbx/gj/Hv0PGlfsQ/6n9skb+bza+2X8I/q1/JL6M/uo82X7z6UvsZ/OrkzUb/ZG/0G+GnuwfdFw6fsPkD/Sg/qf+VuP3C+FfzJ/1p/XN+A/1j3/sX2G/fX8Bf6f8I3S9rS9Xv8m3t17Dfhj/H813589D/t9f9v32E2T9e32E+2D+L56+f3v/p3sP7u138S39f0x/a/f9k4yq52x2/4q+v/nE
"""
        guard let compressed = Data(base64Encoded: s.replacingOccurrences(of: "\n", with: "")) else {
            return []
        }

        var output = [UInt8](repeating: 0, count: 101 * 256)
        let count = compressed.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                compression_decode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!,
                    output.count,
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

        // 强行指定 RGBA 字节序（byteOrder32Big + premultipliedLast，确保内存中 [0]=R, [1]=G, [2]=B, [3]=A）
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let v = max(-50.0, min(50.0, value))
        let raw = Int(v.rounded())
        let index = (raw + 50) * 256

        let lut = Self.brightnessData
        // 边界保护：确保数据完整且查表不会越界
        guard lut.count >= 101 * 256, index >= 0, index + 255 < lut.count else {
            return image
        }

        // 精确对齐通道：[i]=R, [i+1]=G, [i+2]=B，[i+3]=Alpha 保持不动
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i])
            let g = Int(pixels[i + 1])
            let b = Int(pixels[i + 2])

            pixels[i]     = lut[index + r]
            pixels[i + 1] = lut[index + g]
            pixels[i + 2] = lut[index + b]
        }

        guard let result = ctx.makeImage() else { return nil }

        // 还原图片原始方向
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

        // 1. 像素级 LUT 还原美图亮度
        if abs(brightness) > 0.001 {
            guard let result = applyMeituBrightness(output, brightness) else {
                return nil
            }
            output = result
        }

        // 2. 只有在对比度/锐化非 0 时才走 CIContext 烘焙
        if abs(contrast) > 0.001 || sharpness > 0.001 {
            guard let input = CIImage(image: output) else { return output }
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
                if let filter = CISharpenLuminance() { // 使用标准写法
                    filter.setValue(ciOutput, forKey: kCIInputImageKey)
                    filter.setValue(1.0, forKey: "inputRadius")
                    filter.setValue(Float(sharpness / 50.0 * 0.8), forKey: "inputSharpness")
                    if let result = filter.outputImage {
                        ciOutput = result
                    }
                }
            }

            guard let cgImage = context.createCGImage(ciOutput, from: ciOutput.extent) else {
                return output
            }

            return UIImage(
                cgImage: cgImage,
                scale: image.scale,
                orientation: image.imageOrientation
            )
        }

        return output
    }
}
