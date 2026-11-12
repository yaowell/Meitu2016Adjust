import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?

    @State private var brightness: Double = 0
    @State private var contrast: Double = 0
    @State private var sharpness: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                Group {
                    if let image = processedImage ?? originalImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 430)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                Text("请选择照片")
                                    .foregroundColor(.secondary)
                            )
                    }
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("选择照片")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                adjustmentSlider("亮度", $brightness, -100...100)
                adjustmentSlider("对比度", $contrast, -100...100)
                adjustmentSlider("锐度", $sharpness, 0...100)

                Button("恢复原图") {
                    brightness = 0
                    contrast = 0
                    sharpness = 0
                    processedImage = originalImage
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle("2016 调色")
            .onChange(of: selectedItem) { newItem in
                Task {
                    guard let item = newItem,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        return
                    }

                    await MainActor.run {
                        originalImage = image
                        processedImage = image
                        brightness = 0
                        contrast = 0
                        sharpness = 0
                        print("📸 已成功加载照片，尺寸：\(image.size)")
                    }
                }
            }
            .onChange(of: brightness) { _ in processImage() }
            .onChange(of: contrast) { _ in processImage() }
            .onChange(of: sharpness) { _ in processImage() }
        }
    }

    private func processImage() {
        guard let originalImage = originalImage else {
            print("⚠️ 无法调色：originalImage 为 nil（请先选择照片）")
            return
        }

        print("⚙️ 触发调色：亮度=\(brightness), 对比度=\(contrast), 锐度=\(sharpness)")

        let result = Meitu2016AdjustEngine.shared.process(
            originalImage,
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness
        )

        if let result = result {
            print("✅ 调色成功，UI 已更新")
            processedImage = result
        } else {
            print("❌ 调色失败：Meitu2016AdjustEngine 返回了 nil（多半是 LUT .bin 资源文件未成功加载，请检查 tablesReady）")
        }
    }

    private func adjustmentSlider(
        _ name: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .monospacedDigit()
            }

            Slider(value: value, in: range, step: 1)
        }
    }
}
