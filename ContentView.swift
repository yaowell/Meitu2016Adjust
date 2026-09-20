import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var brightness: Double = 0
    @State private var contrast: Double = 0
    @State private var sharpness: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                Group {
                    if let image {
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

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Text("选择照片")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                adjustmentSlider(
                    name: "亮度",
                    value: $brightness,
                    range: -50...50
                )

                adjustmentSlider(
                    name: "对比度",
                    value: $contrast,
                    range: -50...50
                )

                adjustmentSlider(
                    name: "锐度",
                    value: $sharpness,
                    range: -50...50
                )

                Spacer()
            }
            .padding()
            .navigationTitle("2016 调色")
            .task(id: selectedItem) {
                guard let selectedItem else { return }
                image = try? await selectedItem.loadTransferable(type: UIImage.self)
            }
        }
    }

    private func adjustmentSlider(
        name: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 4) {
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