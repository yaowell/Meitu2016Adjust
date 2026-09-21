import UIKit
import CoreImage
import Compression

final class Meitu2016Engine {
    static let shared = Meitu2016Engine()
    
    // 101 x 256 解压后的 LUT 缓存
    private let lutBuffer: [UInt8]

    private init() {
        // 2016 美图 101x256 调光 LUT 密文
        let base64String = """
eNq9nQXbXsURhotDcHf3IMFdgiQ4QYMHKyRYkJYipVSp00IFJziFYsWlpWgIGjRA0SKBhBBXpLI7MzuyO3vO+wXan/Bczz33zDnv+ZJvzDDDjDPNNPPMs8w662yzzz7HHN3mnHOuueeeZ55555tv/gUWWHDBhRZeeJFFF11sscWXWGLJpZZaeullll12ueWXX2HFFVdaaeVVVll1tdVWX737GmusudZaa6/dY5111l1vvfXX32DDDTfaeONNNtl0s80232KLLbfcauute26zzbbbbrf99r16995hxx132mnnXXbZdbfddt+9zx577LnXXnvvvc+++/bdb7/9DzjgwIMOOviQfv0OPeyww4848shvHnX00f0HHHPMsccdf8IJA0886eSTT/nWt0/9zmmnn37Gmd8963tnf/8HP/zRj39yzk9/9vNf/PJXvz73N+ed/7vf/+GPF1508SWXXT7oyquuvva6P93w55tuue0vd9x1z733//XBhx59/Iknn3nuhZdf/cdb//xwxOgJ0/7zDT//vJR/Icue/1LLw3tX3v3pdaX31Xv/m2/34aXf/e9Xv3j0d3L3
"""
        let cleaned = base64String.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: " ", with: "")
        guard let compressedData = Data(base64Encoded: cleaned) else {
            self.lutBuffer = []
            return
        }

        let expectedCount = 101 * 256
        var buffer = [UInt8](repeating: 0, count: expectedCount)
        
        let decompressedCount = compressedData.withUnsafeBytes { srcBuffer in
            buffer.withUnsafeMutableBytes { dstBuffer in
                compression_decode_buffer(
                    dstBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    expectedCount,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    compressedData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        
        self.lutBuffer = Array(buffer.prefix(decompressedCount))
    }

    /// 执行老版美图亮度 LUT 查表
    /// - Parameters:
    ///   - image: 输入图片
    ///   - value: 亮度滑动值 (-50.0 ~ 50.0)
    func process(_ image: UIImage, brightness value: Double) -> UIImage? {
        guard let cgImage = image.cgImage, !lutBuffer.isEmpty else { return image }
        
        // 1. 将 -50 ~ 50 映射到 LUT 行索引 0 ~ 100（默认0映射到第50行）
        let clampedValue = max(-50.0, min(50.0, value))
        let rowIndex = Int((clampedValue + 50.0).rounded())
        
        // 如果处于 0 (第50行原图)，直接返回
        if rowIndex == 50 { return image }
        
        let lutOffset = rowIndex * 256
        guard lutBuffer.count >= lutOffset + 256 else { return image }
        
        let width = cgImage.width
        let height = cgImage.height
        let totalBytes = width * height * 4
        
        // 2. 分配像素内存空间
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        // 强制使用 RGBA 格式，避免小端序（Little-Endian）通道错位
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 3. 内存直接查表映射（C 语言速度，确保 UISlider 滑动实时响应不卡顿）
        lutBuffer.withUnsafeBufferPointer { lutPtr in
            guard let lutBase = lutPtr.baseAddress?.advanced(by: lutOffset) else { return }
            
            pixelData.withUnsafeMutableBufferPointer { pixelsPtr in
                guard let pixels = pixelsPtr.baseAddress else { return }
                
                var i = 0
                while i < totalBytes {
                    pixels[i]     = lutBase[Int(pixels[i])]     // Red
                    pixels[i + 1] = lutBase[Int(pixels[i + 1])] // Green
                    pixels[i + 2] = lutBase[Int(pixels[i + 2])] // Blue
                    // pixels[i + 3] 为 Alpha 通道，不处理
                    i += 4
                }
            }
        }
        
        // 4. 生成新图像
        guard let newCGImage = context.makeImage() else { return nil }
        
        return UIImage(
            cgImage: newCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}
