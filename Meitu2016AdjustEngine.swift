import UIKit
import CoreImage

final class PicsartStyleEngine {
    static let shared = PicsartStyleEngine()
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    private init() {}

    /// 还原美易/老美图的纯粹曝光压暗
    /// - Parameters:
    ///   - image: 输入图片
    ///   - value: 滑块范围 -50.0 ~ 50.0
    func process(_ image: UIImage, brightness value: Double) -> UIImage? {
        if abs(value) < 0.1 { return image }
        guard let inputCI = CIImage(image: image) else { return nil }

        var outputCI = inputCI

        if value < 0 {
            // 【往左拉：纯粹曝光压暗 - 对应美易/老美图的线性乘法】
            // 将 -50 ~ 0 映射为 EV（曝光值） -2.0 ~ 0.0
            let ev = (value / 50.0) * 2.0 
            
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(outputCI, forKey: kCIInputImageKey)
                filter.setValue(ev, forKey: kCIInputEVKey)
                if let res = filter.outputImage { outputCI = res }
            }
        } else {
            // 【往右拉：线性提亮】
            let ev = (value / 50.0) * 1.5
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(outputCI, forKey: kCIInputImageKey)
                filter.setValue(ev, forKey: kCIInputEVKey)
                if let res = filter.outputImage { outputCI = res }
            }
        }

        guard let cgImg = context.createCGImage(outputCI, from: outputCI.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImg, scale: image.scale, orientation: image.imageOrientation)
    }
}
