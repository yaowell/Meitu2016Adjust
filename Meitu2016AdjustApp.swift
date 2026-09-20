import SwiftUI

@main
struct Meitu2016AdjustApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var brightness: Double = 0
    @State private var contrast: Double = 0
    @State private var sharpness: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("2016 调色")
                    .font(.title2)
                    .bold()

                Text("亮度 \(Int(brightness))")
                Slider(value: $brightness, in: -50...50, step: 1)

                Text("对比度 \(Int(contrast))")
                Slider(value: $contrast, in: -50...50, step: 1)

                Text("锐度 \(Int(sharpness))")
                Slider(value: $sharpness, in: -50...50, step: 1)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Meitu 2016")
        }
    }
}