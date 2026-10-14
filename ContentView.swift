import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?

    @State private var brightness: Double = 0
    @State private var contrast: Double = 0
    @State private var sharpness: Double = 0

    @State private var algorithm: BrightnessAlgorithm = .original

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Group {
                    if let image = processedImage ?? originalImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 390)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .overlay {
                                Text("请选择照片")
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 250)
                    }
                }

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Text("选择照片")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 5) {
                    Text("亮度算法")
                        .font(.headline)

                    Picker("亮度算法", selection: $algorithm) {
                        ForEach(BrightnessAlgorithm.allCases) { item in
                            Text(item.rawValue)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                adjustmentSlider(
                    "亮度",
                    $brightness,
                    -50...50
                )

                adjustmentSlider(
                    "对比度",
                    $contrast,
                    -50...50
                )

                adjustmentSlider(
                    "锐度",
                    $sharpness,
                    0...50
                )

                HStack {
                    Button("恢复原图") {
                        brightness = 0
                        contrast = 0
                        sharpness = 0
                        processedImage = originalImage
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("当前算法：\(algorithm.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("2016 调色")
            .onChange(of: selectedItem) { _ in
                Task {
                    guard let item = selectedItem,
                          let data = try? await item.loadTransferable(
                            type: Data.self
                          ),
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
            .onChange(of: brightness) { _ in
                processImage()
            }
            .onChange(of: contrast) { _ in
                processImage()
            }
            .onChange(of: sharpness) { _ in
                processImage()
            }
            .onChange(of: algorithm) { _ in
                processImage()
            }
        }
    }

    private func processImage() {
        guard let originalImage else {
            return
        }

        processedImage = Meitu2016AdjustEngine.shared.process(
            originalImage,
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            algorithm: algorithm
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

            Slider(
                value: value,
                in: range,
                step: 1
            )
        }
    }
}