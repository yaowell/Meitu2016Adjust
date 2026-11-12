import UIKit

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private let tablesReady: Bool = {
        do {
            try MeituLUT.shared.load(bundle: .main)
            return true
        } catch {
            print("[Meitu2016Adjust] LUT load failed: \(error)")
            return false
        }
    }()

    private init() {}

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard tablesReady else { return nil }

        let options = MeituAdjustOptions(
            brightness: Float(max(-100, min(100, brightness))),
            contrast: Float(max(-100, min(100, contrast))),
            sharpen: Float(max(0, min(100, sharpness)))
        )

        return MeituAdjust.process(image, options: options)
    }
}