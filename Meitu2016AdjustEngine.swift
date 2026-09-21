import UIKit
import CoreImage

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])
    
    // 使用 CIColorKernel 直接处理像素 RGB 通道，避免 3D Cube 的插值损失
    private let kernel: CIColorKernel? = {
        let kernelSource = """
        kernel vec4 meituDarkenKernel(__sample image, float amount) {
            vec3 color = image.rgb;
            
            // 1. 经典通道差分压暗：R 压最狠(1.20)，G 次之(1.05)，B 少压(0.40) 以保住蓝天
            vec3 darkOffset = vec3(1.20, 1.05, 0.40) * amount;
            color -= darkOffset;
            
            // 2. 避免压暗后画面发灰：拉升微量对比度 (Boost 1.12)
            color = (color - 0.5) * (1.0 + amount * 0.12) + 0.5;
            
            // 3. 保护极暗部（防止马路和树荫死黑）
            color = max(vec3(0.02), color);
            
            return vec4(clamp(color, 0.0, 1.0), image.a);
        }
        """
        return CIColorKernel(source: kernelSource)
    }()

    private init() {}

    func process(
        _ image: UIImage,
        brightness: Double, // -50 到 50
        contrast: Double,   // -50 到 50
        sharpness: Double   // 0 到 50
    ) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }

        var output = input

        // ========== 1. 亮度（核心负向压暗逻辑） ==========
        if brightness < -0.001 {
            // 归一化 amount 0.0 ~ 0.5
            let amount = Float(-brightness / 50.0 * 0.45)
            
            if let kernel = kernel,
               let result = kernel.apply(extent: output.extent, arguments: [output, amount]) {
                output = result
            }
        } else if brightness > 0.001 {
            // 正向提亮
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(Float(brightness / 50.0 * 0.35), forKey: "inputBrightness")
                if let result = filter.outputImage {
                    output = result
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

        // 渲染 CGImage
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
