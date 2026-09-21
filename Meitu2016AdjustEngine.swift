import UIKit
import CoreImage

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    private init() {}

    func process(
        _ image: UIImage,
        brightness: Double, // -50 到 50
        contrast: Double,   // -50 到 50
        sharpness: Double   // 0 到 50
    ) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }

        var output = input

        // ========== 1. 压暗/提亮 ==========
        if abs(brightness) > 0.001 {
            if brightness < 0 {
                // 负亮度：0.0 到 1.0 归一化强度
                let amount = Float(-brightness / 50.0)
                
                // (1) 强力曝光压暗：从之前的 -0.4EV 提升到 -1.5EV，解决“拉到底都不够暗”的问题
                if let expFilter = CIFilter(name: "CIExposureAdjust") {
                    expFilter.setValue(output, forKey: kCIInputImageKey)
                    expFilter.setValue(-amount * 1.5, forKey: "inputEV")
                    if let result = expFilter.outputImage {
                        output = result
                    }
                }

                // (2) 压中音区暗度（Gamma 沉降）：让画面像美图那样稍微一拉就整体沉下去，不发灰
                if let gammaFilter = CIFilter(name: "CIGammaAdjust") {
                    gammaFilter.setValue(output, forKey: kCIInputImageKey)
                    gammaFilter.setValue(1.0 + amount * 0.85, forKey: "inputPower")
                    if let result = gammaFilter.outputImage {
                        output = result
                    }
                }

                // (3) 高光拉降与暗部保护：防止全图死黑的同时保住蓝天的厚重感
                if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(1.0 - amount * 0.9, forKey: "inputHighlightAmount")
                    filter.setValue(0.0, forKey: "inputShadowAmount")
                    if let result = filter.outputImage {
                        output = result
                    }
                }
            } else {
                // 正亮度：正常提升明度
                if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    filter.setValue(Float(brightness / 50.0 * 0.35), forKey: "inputBrightness")
                    if let result = filter.outputImage {
                        output = result
                    }
                }
            }
        }

        // ========== 2. 对比度 ==========
        if abs(contrast) > 0.001 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(Float(1.0 + contrast / 50.0 * 0.5), forKey: "inputContrast")
                if let result = filter.outputImage {
                    output = result
                }
            }
        }

        // ========== 3. 锐化/清晰度 ==========
        if sharpness > 0.001 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(1.0, forKey: "inputRadius")
                filter.setValue(Float(sharpness / 50.0 * 0.8), forKey: "inputSharpness")
                if let result = filter.outputImage {
                    output = result
                }
            }
        }

        // 4. 渲染生成 CGImage
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }
}
