// ========== 1. 压暗/提亮（2016 美图/美易 深度冷调压暗） ==========
if abs(brightness) > 0.001 {
    if brightness < 0 {
        // 归一化参数 0.0 ~ 1.0
        let amount = Float(-brightness / 50.0)
        
        // 第一步：压高光保蓝天（保留天空细节不爆白，产生深蓝质感）
        if let highlightFilter = CIFilter(name: "CIHighlightShadowAdjust") {
            highlightFilter.setValue(output, forKey: kCIInputImageKey)
            // 压高光强度：随着 amount 增加，高光拉降更狠
            highlightFilter.setValue(1.0 - amount * 0.95, forKey: "inputHighlightAmount")
            highlightFilter.setValue(0.0, forKey: "inputShadowAmount")
            if let result = highlightFilter.outputImage {
                output = result
            }
        }
        
        // 第二步：暗部与中音压暗（加重暗度，解决不够暗的问题）
        // 使用 CIGammaAdjust，inputPower 越大整体暗部沉降越深（1.0 是原图，最大压到 1.6~1.8）
        if let gammaFilter = CIFilter(name: "CIGammaAdjust") {
            gammaFilter.setValue(output, forKey: kCIInputImageKey)
            let gammaPower = 1.0 + amount * 0.75  // 可调节这个系数（如 0.75 -> 0.95）来进一步加重暗度
            gammaFilter.setValue(gammaPower, forKey: "inputPower")
            if let result = gammaFilter.outputImage {
                output = result
            }
        }
        
        // 第三步：适度下调曝光，让整体画面彻底深沉下去
        if let expFilter = CIFilter(name: "CIExposureAdjust") {
            expFilter.setValue(output, forKey: kCIInputImageKey)
            expFilter.setValue(-amount * 0.65, forKey: "inputEV")
            if let result = expFilter.outputImage {
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
