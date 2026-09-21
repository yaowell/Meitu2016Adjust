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

        // ========== 1. 压暗/提亮（Ins / 美易 风格保细节算法） ==========
        if abs(brightness) > 0.001 {
            if brightness < 0 {
                // 负亮度：使用 CIHighlightShadowAdjust 压高光、保暗部，还原 2016 深冷蓝质感
                // amount 范围从 0.0 到 1.0
                let amount = Float(-brightness / 50.0)
                
                if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
                    filter.setValue(output, forKey: kCIInputImageKey)
                    // inputHighlightAmount: 1.0 为正常，越低（如 0.0）高光压得越深
                    filter.setValue(1.0 - amount * 0.8, forKey: "inputHighlightAmount")
                    // inputShadowAmount: 保持暗部不塌陷，微调保细节
                    filter.setValue(0.0, forKey: "inputShadowAmount")
                    
                    if let result = filter.outputImage {
                        output = result
                    }
                }
                
                // 叠加微弱曝光补偿，增加画面通透度
                if let expFilter = CIFilter(name: "CIExposureAdjust") {
                    expFilter.setValue(output, forKey: kCIInputImageKey)
                    expFilter.setValue(Float(brightness / 50.0 * 0.4), forKey: "inputEV")
                    if let result = expFilter.outputImage {
                        output = result
                    }
                }
            } else {
                // 正亮度：正常使用 CIColorControls 提升整体明度
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

        // 渲染生成 CGImage
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
