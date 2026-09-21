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
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard let input = CIImage(image: image) else {
            return nil
        }

        var output = input

        // 1. 亮度处理：负数保留老美图 R/G/B 分通道 3D LUT 压暗；正数使用 CIColorControls
        if brightness < -0.001 {
            output = applyOldMeituBrightness(
                output,
                amount: min(1.0, -brightness / 50.0)
            )
        } else if brightness > 0.001 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(Float(brightness / 50.0 * 0.55), forKey: "inputBrightness")
                filter.setValue(Float(1.0), forKey: "inputContrast")
                filter.setValue(Float(1.0), forKey: "inputSaturation")
                if let result = filter.outputImage {
                    output = result
                }
            }
        }

        // 2. 对比度处理：基于传统 CIColorControls 调节
        if abs(contrast) > 0.001 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(Float(0.0), forKey: "inputBrightness")
                filter.setValue(Float(1.0 + contrast / 50.0 * 0.65), forKey: "inputContrast")
                filter.setValue(Float(1.0), forKey: "inputSaturation")
                if let result = filter.outputImage {
                    output = result
                }
            }
        }

        // 3. 锐化/清晰度处理：兼容性 CISharpenLuminance 接口
        if sharpness > 0.001 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(output, forKey: kCIInputImageKey)
                filter.setValue(Float(1.0), forKey: "inputRadius")
                filter.setValue(Float(sharpness / 50.0 * 0.8), forKey: "inputSharpness")
                if let result = filter.outputImage {
                    output = result
                }
            }
        }

        guard let cgImage = context.createCGImage(
            output,
            from: output.extent
        ) else {
            return nil
        }

        return UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    // ========== 【备选算法：CLImageEditor 的 Gamma + 曝光 EV 调色】 ==========
    /// 提取自 CLImageEditor 经典算子（将亮度转为 EV 曝光，对比度转为 Gamma 曲线）
    private func applyCLStyleAdjustment(
        _ image: CIImage,
        brightness: Double,
        contrast: Double,
        saturation: Double = 1.0
    ) -> CIImage {
        var currentImage = image

        // 饱和度
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(currentImage, forKey: kCIInputImageKey)
            filter.setValue(Float(saturation), forKey: "inputSaturation")
            if let out = filter.outputImage { currentImage = out }
        }

        // 亮度 (CLImageEditor 映射: 2 * brightness -> inputEV)
        if abs(brightness) > 0.001 {
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(currentImage, forKey: kCIInputImageKey)
                filter.setValue(Float(brightness * 2.0), forKey: "inputEV")
                if let out = filter.outputImage { currentImage = out }
            }
        }

        // 对比度 (CLImageEditor 映射: contrast^2 -> inputPower Gamma)
        if abs(contrast - 1.0) > 0.001 {
            if let filter = CIFilter(name: "CIGammaAdjust") {
                filter.setValue(currentImage, forKey: kCIInputImageKey)
                filter.setValue(Float(contrast * contrast), forKey: "inputPower")
                if let out = filter.outputImage { currentImage = out }
            }
        }

        return currentImage
    }

    // ========== 【重写这里：分通道亮度，R G压暗多，蓝色少压】 ==========
    private func applyOldMeituBrightness(
        _ image: CIImage,
        amount: Double
    ) -> CIImage {
        let size = 32
        var cube = [Float]()
        cube.reserveCapacity(size * size * size * 4)

        // 权重，和GLSL保持一致：R*1.15  G*1.10  B*0.45
        let rWeight: Double = 1.15
        let gWeight: Double = 1.10
        let bWeight: Double = 0.45
        let contrastBoost: Double = 1.08

        for b in 0..<size {
            let blue = Double(b) / Double(size - 1)
            for g in 0..<size {
                let green = Double(g) / Double(size - 1)
                for r in 0..<size {
                    let red = Double(r) / Double(size - 1)

                    // 分通道偏移
                    var rr = red - amount * rWeight
                    var gg = green - amount * gWeight
                    var bb = blue - amount * bWeight

                    // 小幅对比度拉升，防止压暗发灰
                    rr = (rr - 0.5) * contrastBoost + 0.5
                    gg = (gg - 0.5) * contrastBoost + 0.5
                    bb = (bb - 0.5) * contrastBoost + 0.5

                    // clamp 0~1
                    rr = max(0.0, min(1.0, rr))
                    gg = max(0.0, min(1.0, gg))
                    bb = max(0.0, min(1.0, bb))

                    cube.append(Float(rr))
                    cube.append(Float(gg))
                    cube.append(Float(bb))
                    cube.append(1.0)
                }
            }
        }

        let data = cube.withUnsafeBufferPointer {
            Data(buffer: $0)
        }

        if let filter = CIFilter(name: "CIColorCube") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(size, forKey: "inputCubeDimension")
            filter.setValue(data, forKey: "inputCubeData")
            return filter.outputImage ?? image
        }

        return image
    }
}
