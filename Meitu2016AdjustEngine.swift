import UIKit
import CoreGraphics
import Compression

final class Meitu2016AdjustEngine {
    static let shared = Meitu2016AdjustEngine()

    private static let lutCompressed = Data(base64Encoded: """
eNrtnfejZ1V1xS3UYSjD0EEQRDoiRQUUsVAUUATpoICGpoCOVCkGg0hoA0pg6DUYiQU1RCXEaNSoFCFEQBQYpM5QZhiYGYoUc885++x+zj33vTf8xJ+w3l77
s/a973v3fsMb3/imN715vvnmX2CBBRdcaOGFxy2yyPjxiy622OJLLDFhwpITJy619NLLLLPscsstv8IKK6640lvesvIqq7z1rauuttrbVl/97W9fY80111p7
7XXWWXe99dZ/xzs22OCdG2640UYbb7LJu9797ve8Z9PNNtv8ve993/u2eP/7t/zABz74wQ99+MNbbb31Ntts+5GPfHS77bbffoePfezjO+74iU/stPPOn9xl
l1132233PfbYc6+99t5nn099+tP77rf//p/57Gf/7oADDzzo4EM+97nPH3rY4Yd/4YuTvvSlI4486uhjjv3ycccdf8KJX/n7k776Dyd/7ZSvn/qPp51+xlmT
zz7nG98897zzp1xw0cWXXHb5FVddfc23vn3td777/R/88N/+/Sc33Pizn//3r/7ndzf//vb/u+ue+x54ePpTz77wtzd0+t8M+hcC/YuC/iVB/7KgfyXQv+qq
q70t6F9jjTXXCvrXXXe99YP+d74zyN94k3e9K8jfdLPNNw/yt3j/llsG+R/68FZbgfyPgvyPg/xP7rLrrrvtvvsee+651957J/n7MfmHBPmHBfmTQH6n38g/
86zJQf4/nTflggsvuuTSy6648qp/vuZfvv2v3/nedT/40fU/jvp/+evf/O6W3//vH+7+031/eWT6jLL+xUH/UqB/+eVD+Vd6y8orh/JH/an8a0H514fybwzl
3xTKvwWUP8nfeptttw3yt9t+hx1A/k5G/qeS/M908g/o5B8c5B8a5H8xyY/l9+R35e/knz/lQlX+67ry//in//Gf//WLX/76tzfdctsdnf77ff3jSP8E0J/s
vzzYf2Vr/3XB/rL8m0H5pfu3Bfcn+TsW5O+r5H+eyT8K5Qv9ZzL3X3jxJZdefsWVV7Pyo/1/e/Ott99x5x//fP+Djzzu6x9P+ieSftb+0v7rgP1N+TeH8hv3
s+bfyTQ/k9+5/6CDUP4Xonxo/uPr7r/40ssuv5KX//pQ/k5/Z//Y/n/889QHH+X65xf6FyP9sv2N/Rn9TPkZ/KT7ZfNr9u2b2IfyiX1HAPua3N+V/1u5/IF+
yf6/ualr/w5/90596NHHZ84u619C6Jftn+y/Btkfy7+RKH+Sv6Vwv2z+JD+5v4L+wzj6y81P7k/wy+Xv6PfTbP+bbr2tw9899z7w0GNPSP0Lav0GfwX7l8uf
3P8B7f5K8/ehn9gn9Sf5XfnB/R38uvJf25X/+7H8QL/O/qH9O/y7+hd29GP7p/Kvou3fV/6C+4vsq6Ef2eeVP8qP0R/gJ8sf6Jf039K1/51/7OLvYV+/iT+l
n9tflX9Dv/zK/aXBp4b+fvaR+0P0J/hB+VP4ZfvH9u/w/5eHpz3x9OwXy/pt+3P7y/BH+1fKr9zvsK+O/j72ofsBfl325fJn+sX069r/rns6/Y9Me3LU+pX9
A7H7e/gXz7+cv1qACoCsG6A4gQ8VH9x+m27iG7wp8afkn7zClQAsLEBBAD1EzB/AXKiugqM4y/iX+Cv0f4+/uT4g/r/HzsYFkM=
""")

    private static let lut: [UInt8] = {
        var out = [UInt8](repeating: 0, count: 57600)
        let count = lutCompressed.withUnsafeBytes { raw in
            compression_decode_buffer(
                &out,
                out.count,
                raw.bindMemory(to: UInt8.self).baseAddress!,
                raw.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        precondition(count == out.count)
        return out
    }()

    func process(
        _ image: UIImage,
        brightness: Double,
        contrast: Double,
        sharpness: Double
    ) -> UIImage? {
        guard let cg = image.cgImage else { return nil }

        let width = cg.width
        let height = cg.height
        let rowBytes = width * 4

        var data = [UInt8](repeating: 0, count: rowBytes * height)

        let space = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        ctx.draw(
            cg,
            in: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )

        applyOriginalLUTs(
            &data,
            brightness: brightness,
            contrast: contrast
        )

        if sharpness != 0 {
            applySharpen(
                &data,
                width: width,
                height: height,
                value: sharpness
            )
        }

        guard let out = ctx.makeImage() else {
            return nil
        }

        return UIImage(
            cgImage: out,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    private func applyOriginalLUTs(
        _ data: inout [UInt8],
        brightness: Double,
        contrast: Double
    ) {
        let b = Float(
            max(
                -100.0,
                min(100.0, brightness)
            )
        )

        let c = Float(
            max(
                -100.0,
                min(100.0, contrast)
            )
        )

        let brightnessIndex = Int(
            b * 1.5 + 0.5
        )

        let contrastIndex =
            c < 0
            ? Int(c)
            : Int(c * 0.5 + 0.5)

        applyPass(
            &data,
            brightnessIndex: brightnessIndex,
            contrastIndex: contrastIndex
        )

        applyPass(
            &data,
            brightnessIndex: brightnessIndex,
            contrastIndex: contrastIndex
        )
    }

    private func applyPass(
        _ data: inout [UInt8],
        brightnessIndex: Int,
        contrastIndex: Int
    ) {
        if let offset = brightnessOffset(brightnessIndex) {
            applyLUT(
                &data,
                offset: offset
            )
        }

        if let offset = contrastOffset(contrastIndex) {
            applyLUT(
                &data,
                offset: offset
            )
        }
    }

    private func brightnessOffset(
        _ index: Int
    ) -> Int? {
        if index < 0 {
            guard index >= -75 else {
                return nil
            }

            return (index + 75) * 256
        }

        if index > 0 {
            guard index <= 75 else {
                return nil
            }

            return (75 + index - 1) * 256
        }

        return nil
    }

    private func contrastOffset(
        _ index: Int
    ) -> Int? {
        if index < 0 {
            guard index >= -50 else {
                return nil
            }

            return (150 + index) * 256
        }

        if index > 0 {
            guard index <= 25 else {
                return nil
            }

            return (150 + index - 1) * 256
        }

        return nil
    }

    private func applyLUT(
        _ data: inout [UInt8],
        offset: Int
    ) {
        for i in stride(
            from: 1,
            to: data.count,
            by: 4
        ) {
            data[i] =
                Self.lut[
                    offset + Int(data[i])
                ]

            data[i + 1] =
                Self.lut[
                    offset + Int(data[i + 1])
                ]

            data[i + 2] =
                Self.lut[
                    offset + Int(data[i + 2])
                ]
        }
    }

    private func applySharpen(
        _ data: inout [UInt8],
        width: Int,
        height: Int,
        value: Double
    ) {
        let s = Float(value / 50.0)

        if s == 0 {
            return
        }

        let src = data
        let center = 1.0 + 4.0 * s

        for y in 0..<height {
            let ym = max(0, y - 1)
            let yp = min(height - 1, y + 1)

            for x in 0..<width {
                let xm = max(0, x - 1)
                let xp = min(width - 1, x + 1)

                let i = (y * width + x) * 4
                let l = (y * width + xm) * 4
                let r = (y * width + xp) * 4
                let t = (ym * width + x) * 4
                let b = (yp * width + x) * 4

                for channel in 1...3 {
                    let v =
                        Float(src[i + channel]) * center
                        -
                        Float(
                            src[l + channel]
                            + src[r + channel]
                            + src[t + channel]
                            + src[b + channel]
                        ) * s

                    data[i + channel] =
                        UInt8(
                            max(
                                0,
                                min(
                                    255,
                                    Int(v.rounded())
                                )
                            )
                        )
                }
            }
        }
    }
}