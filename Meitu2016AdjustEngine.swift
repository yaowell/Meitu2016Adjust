import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    // 缓存上一次计算的 cube 数据，防止拖动滑块时重复计算造成卡顿
    private var lastCubeAmount: Double = -1.0
    private var cachedCubeData: Data?

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

        // 1. 亮度调整（负值走老美图特色 3D 调色，正值走标准亮暗调节）
        if brightness < -0.001 {
            let amount = min(1.0, -brightness / 50.0)
            output = applyOldMeituBrightness(output, amount: amount)
        } else if brightness > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = Float(brightness / 50.0 * 0.55)
            filter.contrast = 1.0
            filter.saturation = 1.0

            if let result = filter.outputImage {
                output = result
            }
        }

        // 2. 对比度调整
        if abs(contrast) > 0.001 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.brightness = 0
            filter.contrast = Float(1.0 + contrast / 50.0 * 0.65)
            filter.saturation = 1.0

            if let result = filter.outputImage {
                output = result
            }
        }

        // 3. 锐度调整
        if sharpness > 0.001 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.radius = 1.0
            filter.sharpness = Float(sharpness / 50.0 * 0.8)

            if let result = filter.outputImage {
                output = result
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

    private func applyOldMeituBrightness(
        _ image: CIImage,
        amount: Double
    ) -> CIImage {
        // 量化强度，避免浮点数微小抖动触发不必要的重新计算
        let quantizedAmount = CoreGraphics.round(amount * 100.0) / 100.0
        
        let data: Data
        if let cached = cachedCubeData, abs(lastCubeAmount - quantizedAmount) < 0.001 {
            data = cached
        } else {
            data = generateOldMeituCubeData(amount: quantizedAmount)
            cachedCubeData = data
            lastCubeAmount = quantizedAmount
        }

        let filter = CIFilter.colorCube()
        filter.inputImage = image
        filter.cubeDimension = 32
        filter.cubeData = data

        return filter.outputImage ?? image
    }

    /// 生成老美图暗部质感/青蓝倾向的 3D Color Cube 数据
    private func generateOldMeituCubeData(amount: Double) -> Data {
        let size = 32
        var cube = [Float]()
        cube.reserveCapacity(size * size * size * 4)

        for b in 0..<size {
            let blue = Double(b) / Double(size - 1)

            for g in 0..<size {
                let green = Double(g) / Double(size - 1)

                for r in 0..<size {
                    let red = Double(r) / Double(size - 1)

                    // 1. 非线性 Gamma 压暗（比单纯乘法更有层次感）
                    let gamma = 1.0 + amount * 0.8
                    var rr = pow(red, gamma)
                    var gg = pow(green, gamma)
                    var bb = pow(blue, gamma)

                    // 2. 计算当前点的亮度 (Luma)
                    let luma = 0.2126 * rr + 0.7152 * gg + 0.0722 * bb

                    // 3. 经典美图/胶片风格的“暗部青蓝倾向”(Shadow Cyan Shift)
                    let shadowWeight = max(0.0, 1.0 - luma * 2.2)
                    bb += amount * shadowWeight * 0.12
                    rr -= amount * shadowWeight * 0.04

                    // 4. 适度增强饱和度，防止画面发灰
                    let saturation = 1.0 + amount * 0.15
                    let mid = 0.299 * rr + 0.587 * gg + 0.114 * bb
                    rr = mid + (rr - mid) * saturation
                    gg = mid + (gg - mid) * saturation
                    bb = mid + (bb - mid) * saturation

                    // 5. 边界裁剪
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

        return cube.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
