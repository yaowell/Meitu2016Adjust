import UIKit
import CoreImage

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    
    // 编译你的核心色彩 Kernel（完美还原 RGB 通道差分压暗、保蓝天与防灰对比度）
    private lazy var meituBrightnessKernel: CIColorKernel? = {
        let kernelCode = """
        kernel vec4 meituBrightness(__unsafe_unretained CIImage img, float uBrightness) {
            vec4 c = sample(img, destCoord());
            
            // 核心：R、G压暗幅度更大，B通道少压一点，保住蓝天
            c.r += uBrightness * 1.15;
            c.g += uBrightness * 1.10;
            c.b += uBrightness * 0.45; 

            // 对比度拉升，防止压暗之后发灰
            c.rgb = (c.rgb - 0.5) * 1.08 + 0.5;
            
            return clamp(c, 0.0, 1.0);
        }
        """
        return CIColorKernel(source: kernelCode)
    }()

    private init() {}

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        var output = input

        // 1. 亮度调节（负值为压暗，正值为提亮）
        if brightness < -0.001 {
            let uBrightness = Float(brightness / 50.0 * 0.5) // 将 -50 映射为合适的负向偏移量
            if let kernel = meituBrightnessKernel,
               let filtered = kernel.apply(extent: output.extent, arguments: [output, uBrightness]) {
                output = filtered
            }
        } else if brightness > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = Float(brightness / 50.0 * 0.55)
            filter.contrast = 1.0
            filter.saturation = 1.0
            if let result = filter.outputImage { output = result }
        }

        // 2. 对比度调节
        if abs(contrast) > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = 0
            filter.contrast = Float(1.0 + contrast / 50.0 * 0.65)
            filter.saturation = 1.0
            if let result = filter.outputImage { output = result }
        }

        // 3. 锐度调节
        if sharpness > 0.001 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.radius = 1.0
            filter.sharpness = Float(sharpness / 50.0 * 0.8)
            if let result = filter.outputImage { output = result }
        }

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
