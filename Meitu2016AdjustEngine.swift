import CoreImage
import UIKit

public class Meitu2016AdjustEngine {
    
    // MARK: - Properties
    
    private let context: CIContext
    private var kernel: CIColorKernel?
    private let cache = NSCache<NSString, CIImage>()
    
    /// 亮度调节 (-1.0 ~ 1.0)
    public var brightness: Float = 0.0 { didSet { clearCache() } }
    
    /// 对比度调节 (0.0 ~ 2.0)
    public var contrast: Float = 1.0 { didSet { clearCache() } }
    
    /// 饱和度调节 (0.0 ~ 2.0)
    public var saturation: Float = 1.0 { didSet { clearCache() } }
    
    /// 经典冷色调与暗部质感强度 (0.0 ~ 1.0)
    public var vintageTone: Float = 0.0 { didSet { clearCache() } }
    
    // MARK: - Initialization
    
    public init(context: CIContext = CIContext(options: [.workingColorSpace: NSNull()])) {
        self.context = context
        setupKernel()
    }
    
    // MARK: - Kernel Setup
    
    private func setupKernel() {
        // 使用 CIColorKernel 直接处理像素，高效还原 2016 经典冷调与暗部质感
        let kernelSource = """
        kernel vec4 meitu2016Adjust(__sample image, float brightness, float contrast, float saturation, float vintageTone) {
            vec4 color = image;
            
            // 1. 基础亮度与对比度调整
            color.rgb += brightness;
            color.rgb = (color.rgb - 0.5) * contrast + 0.5;
            
            // 2. 饱和度调整
            float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
            color.rgb = mix(vec3(luminance), color.rgb, saturation);
            
            // 3. 标志性冷色调与暗部压暗（针对暗部进行局部微调）
            vec3 darkTint = vec3(0.92, 0.96, 1.0);
            color.rgb = mix(color.rgb, color.rgb * darkTint, vintageTone * (1.0 - luminance));
            
            return clamp(color, 0.0, 1.0);
        }
        """
        self.kernel = CIColorKernel(source: kernelSource)
    }
    
    // MARK: - Processing
    
    public func process(image: CIImage) -> CIImage {
        // 生成当前参数的缓存 Key，优化滑块实时拖动性能
        let cacheKey = NSString(format: "%.2f_%.2f_%.2f_%.2f", brightness, contrast, saturation, vintageTone)
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        guard let kernel = kernel else { return image }
        
        let extent = image.extent
        guard let processedImage = kernel.apply(extent: extent, arguments: [image, brightness, contrast, saturation, vintageTone]) else {
            return image
        }
        
        cache.setObject(processedImage, forKey: cacheKey)
        return processedImage
    }
    
    // MARK: - Cache Management
    
    public func clearCache() {
        cache.removeAllObjects()
    }
}
