import SwiftUI

struct ContentView: View {
    @State private var inputImage: UIImage? = UIImage(systemName: "photo")
    @State private var processedImage: UIImage?
    
    // 美图2016 LUT 亮度调节范围 (-50.0 ~ 50.0)
    @State private var brightness: Double = 0.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 图片展示区域
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                    
                    if let image = processedImage ?? inputImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding(8)
                    } else {
                        Text("未选择图片")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // 参数控制面板
                VStack(spacing: 12) {
                    HStack {
                        Text("亮度")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text(String(format: "%.1f", brightness))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    
                    // 滑块映射美图 2016 引擎的 -50 ~ 50 范围
                    Slider(value: $brightness, in: -50.0...50.0, step: 1.0) { editing in
                        if !editing {
                            applyFilter()
                        }
                    }
                    .onChange(of: brightness) { newValue in
                        applyFilter()
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("美图2016调光")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // 调用 Meitu2016Engine 图像处理逻辑
    private func applyFilter() {
        guard let input = inputImage else { return }
        
        // 此处只传递 image 与 brightness，匹配 Meitu2016Engine.shared.process 定义
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Meitu2016Engine.shared.process(input, brightness: self.brightness)
            DispatchQueue.main.async {
                self.processedImage = result
            }
        }
    }
}

#Preview {
    ContentView()
}
