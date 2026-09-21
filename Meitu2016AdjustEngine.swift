import UIKit
import CoreImage
import Compression

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    // 2016 美图秀秀 101x256 调光曲线矩阵
    private static let brightnessData: [UInt8] = {
        let s = """
eNq9nQXbXsURhotDcHf3IMFdgiQ4QYMHKyRYkJYipVSp00IFJziFYsWlpWgIGjRA0SKBhBBXpLI7MzuyO3vO+wXan/Bczz33zDnv+ZJvzDDDjDPNNPPMs8w662yzzz7HHN3mnHOuueeeZ55555tv/gUWWHDBhRZeeJFFF11sscWXWGLJpZZaeullll12ueWXX2HFFVdaaeVVVll1tdVWX737GmusudZaa6/dY5111l1vvfXX32DDDTfaeONNNtl0s80232KLLbfcauute26zzbbbbrf99r16995hxx132mnnXXbZdbfddt+9zx577LnXXnvvvc+++/bdb7/9DzjgwIMOOviQfv0OPeyww4848shvHnX00f0HHHPMsccdf8IJA0886eSTT/nWt0/9zmmnn37Gmd8963tnf/8HP/zRj39yzk9/9vNf/PJXvz73N+ed/7vf/+GPF1508SWXXT7oyquuvva6P93w55tuue0vd9x1z733//XBhx59/Iknn3nuhZdf/cdb//xwxOgJ0/7zDT//vJR/Icue/1LLw3tX3v3pdaX31Xv/m2/34aXf/e9Xv3j0d3L3
"""
        // 解压 101 * 256 字节的 LUT 数据
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
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height

        // 1. 将滑动条 (-50.0 ~ 50.0) 映射到 0 ~ 100 索引
        let clampedValue = max(-50.0, min(50.0, value))
        // 0 对应中心点 50
        let curveIndex = Int((clampedValue + 50.0).rounded())
        
        // 如果亮度变动极小，直接返回原图
        if curveIndex == 50 { return image }

        let lutOffset = curveIndex * 256
        guard Self.brightnessData.count >= lutOffset + 256 else { return image }

        // 取出当前 slider 位置对应的 256 字节映射表
        let lut = Array(Self.brightnessData[lutOffset..<(lutOffset + 256)])

        // 2. 提取 RGBA 像素数据
        var rawData = [UInt8](repeating: 0, count: totalPixels * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 3. 逐像素查表映射 (RGBA 顺序: R=0, G=1, B=2, A=3)
        // 采用指针直接操作提升处理速度，避免滑动卡顿
        rawData.withUnsafeMutableBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return }
            var i = 0
            let len = totalPixels * 4
            while i < len {
                ptr[i]     = lut[Int(ptr[i])]     // Red
                ptr[i + 1] = lut[Int(ptr[i + 1])] // Green
                ptr[i + 2] = lut[Int(ptr[i + 2])] // Blue
                // ptr[i + 3] 是 Alpha，保持不变
                i += 4
            }
        }

        // 4. 生成映射后的图像
        guard let newCGImage = context.makeImage() else { return nil }

        return UIImage(
            cgImage: newCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    /// 对外调用的主要方法
    func process(
        _ image: UIImage,
        brightness: Double, // 范围: -50.0 到 50.0
        contrast: Double = 0.0,
        sharpness: Double = 0.0
    ) -> UIImage? {
        var output = image

        // 1. 优先应用美图 2016 经典暗调/亮调曲线
        if abs(brightness) > 0.1 {
            if let result = applyMeituBrightness(output, brightness) {
                output = result
            }
        }

        // 如果不需要调整对比度和锐化，直接返回曲线处理后的图片
        if abs(contrast) <= 0.1 && sharpness <= 0.1 {
            return output
        }

        // 2. 叠加 CoreImage 的辅助微调
        guard let inputCI = CIImage(image: output) else { return output }
        var ciOutput = inputCI

        if abs(contrast) > 0.1 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciOutput, forKey: kCIInputImageKey)
                // 模拟老版拉低亮度时的对比度补偿
                let contrastFactor = 1.0 + (contrast / 50.0) * 0.3
                filter.setValue(Float(contrastFactor), forKey: "inputContrast")
                if let res = filter.outputImage { ciOutput = res }
            }
        }

        if sharpness > 0.1 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(ciOutput, forKey: kCIInputImageKey)
                filter.setValue(1.0, forKey: "inputRadius")
                filter.setValue(Float((sharpness / 50.0) * 0.6), forKey: "inputSharpness")
                if let res = filter.outputImage { ciOutput = res }
            }
        }

        guard let cgImg = context.createCGImage(ciOutput, from: ciOutput.extent) else {
            return output
        }

        return UIImage(cgImage: cgImg, scale: image.scale, orientation: image.imageOrientation)
    }
}
