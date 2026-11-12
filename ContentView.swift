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
            .onChange(of: selectedItem) { _ in
                Task {
                    guard let item = selectedItem,
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
                    }
                }
            }
            .onChange(of: brightness) { _ in processImage() }
            .onChange(of: contrast) { _ in processImage() }
            .onChange(of: sharpness) { _ in processImage() }
        }
    }

    private func processImage() {
        guard let originalImage else { return }

        processedImage = Meitu2016AdjustEngine.shared.process(
            originalImage,
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness
        )
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