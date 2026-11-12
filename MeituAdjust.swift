import Accelerate
import CoreGraphics
import Foundation
import UIKit

public struct MeituAdjustOptions {
    /// -100 … 100
    public var brightness: Float
    /// -100 … 100
    public var contrast: Float
    /// 0 … 100
    public var sharpen: Float

    public init(
        brightness: Float = 0,
        contrast: Float = 0,
        sharpen: Float = 0
    ) {
        self.brightness = brightness
        self.contrast = contrast
        self.sharpen = sharpen
    }

    public var isIdentity: Bool {
        brightness == 0 && contrast == 0 && sharpen == 0
    }
}

public enum MeituAdjust {

    // MARK: - 入口

    public static func process(
        _ image: UIImage,
        options: MeituAdjustOptions
    ) -> UIImage? {
        guard let cg = image.cgImage,
              let out = process(cg, options: options) else {
            return nil
        }

        return UIImage(
            cgImage: out,
            scale: image.scale,
            orientation: image.imageOrientation
        )
    }

    public static func process(
        _ cgImage: CGImage,
        options: MeituAdjustOptions
    ) -> CGImage? {
        if options.isIdentity {
            return cgImage
        }

        let w = cgImage.width
        let h = cgImage.height

        guard w > 0, h > 0 else {
            return nil
        }

        let rowBytes = align64(w * 4)
        let byteCount = rowBytes * h

        let data = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: 64
        )

        defer {
            data.deallocate()
        }

        var buf = vImage_Buffer(
            data: data,
            height: vImagePixelCount(h),
            width: vImagePixelCount(w),
            rowBytes: rowBytes
        )

        guard draw(cgImage, into: &buf) else {
            return nil
        }

        // 亮度
        if options.brightness != 0 {
            lut(
                &buf,
                table: MeituLUT.shared.brightnessTableU8(
                    slider: options.brightness
                )
            )
        }

        // 对比度
        if options.contrast != 0 {
            lut(
                &buf,
                table: MeituLUT.shared.contrastTableU8(
                    slider: options.contrast
                )
            )
        }

        // 锐度
        if options.sharpen > 0 {
            let level = min(
                max(options.sharpen, 0),
                100
            ) / 100

            unsharpMask(&buf, level: level)
        }

        return makeCGImage(&buf)
    }

    // MARK: - 亮度 / 对比度

    private static func lut(
        _ buf: inout vImage_Buffer,
        table: [UInt8]
    ) {
        let h = Int(buf.height)

        let out = UnsafeMutableRawPointer.allocate(
            byteCount: buf.rowBytes * h,
            alignment: 64
        )

        defer {
            out.deallocate()
        }

        var dst = vImage_Buffer(
            data: out,
            height: buf.height,
            width: buf.width,
            rowBytes: buf.rowBytes
        )

        var t = table
        var identity = IDENTITY

        let err: vImage_Error =
            t.withUnsafeMutableBufferPointer { tp in
                identity.withUnsafeMutableBufferPointer { ap in

                    vImageTableLookUp_ARGB8888(
                        &buf,
                        &dst,
                        tp.baseAddress,
                        tp.baseAddress,
                        tp.baseAddress,
                        ap.baseAddress,
                        vImage_Flags(kvImageNoFlags)
                    )
                }
            }

        if err == kvImageNoError {
            memcpy(
                buf.data,
                dst.data,
                buf.rowBytes * h
            )
        }
    }

    private static let IDENTITY: [UInt8] =
        (0..<256).map { UInt8($0) }

    // MARK: - 锐化

    public static func blurRadius(
        width: Int,
        height: Int
    ) -> Int {
        let r = Int(
            (
                Double(width * height) / 294912.0 + 0.5
            ).rounded(.toNearestOrEven)
        )

        return max(1, r)
    }

    private static func unsharpMask(
        _ buf: inout vImage_Buffer,
        level: Float
    ) {
        let w = Int(buf.width)
        let h = Int(buf.height)

        let radius = blurRadius(width: w, height: h)
        let kernel = UInt32(radius * 2 + 1)

        let tmpBytes = buf.rowBytes * h

        let p1 = UnsafeMutableRawPointer.allocate(
            byteCount: tmpBytes,
            alignment: 64
        )

        let p2 = UnsafeMutableRawPointer.allocate(
            byteCount: tmpBytes,
            alignment: 64
        )

        defer {
            p1.deallocate()
            p2.deallocate()
        }

        var tmp1 = vImage_Buffer(
            data: p1,
            height: buf.height,
            width: buf.width,
            rowBytes: buf.rowBytes
        )

        var tmp2 = vImage_Buffer(
            data: p2,
            height: buf.height,
            width: buf.width,
            rowBytes: buf.rowBytes
        )

        var bg: [UInt8] = [0, 0, 0, 255]
        let flags = vImage_Flags(kvImageEdgeExtend)

        guard vImageBoxConvolve_ARGB8888(
            &buf,
            &tmp1,
            nil,
            0,
            0,
            kernel,
            1,
            &bg,
            flags
        ) == kvImageNoError,

        vImageBoxConvolve_ARGB8888(
            &tmp1,
            &tmp2,
            nil,
            0,
            0,
            1,
            kernel,
            &bg,
            flags
        ) == kvImageNoError else {
            return
        }

        let k = 4.0 * Double(
            min(max(level, 0), 1)
        )

        var alpha = Float(1.0 + k)
        var beta = Float(-k)

        let n = vDSP_Length(buf.rowBytes * h)

        let orig = buf.data.assumingMemoryBound(
            to: UInt8.self
        )

        let blur = tmp2.data.assumingMemoryBound(
            to: UInt8.self
        )

        var origF = [Float](
            repeating: 0,
            count: Int(n)
        )

        var blurF = [Float](
            repeating: 0,
            count: Int(n)
        )

        vDSP_vfltu8(
            orig, 1,
            &origF, 1,
            n
        )

        vDSP_vfltu8(
            blur, 1,
            &blurF, 1,
            n
        )

        var outF = [Float](
            repeating: 0,
            count: Int(n)
        )

        vDSP_vsmul(
            &origF, 1,
            &alpha,
            &outF, 1,
            n
        )

        // 引入独立的 tempResult 数组，避免同一变量既作输入又作输出的独占访问冲突
        var tempResult = [Float](
            repeating: 0,
            count: Int(n)
        )

        vDSP_vsma(
            &blurF, 1,
            &beta,
            &outF, 1,
            &tempResult, 1,
            n
        )

        var lo: Float = 0
        var hi: Float = 255

        // 同样引入 clippedResult 数组以避免 vIP clip 时的独占冲突
        var clippedResult = [Float](
            repeating: 0,
            count: Int(n)
        )

        vDSP_vclip(
            &tempResult, 1,
            &lo, &hi,
            &clippedResult, 1,
            n
        )

        var outU8 = [UInt8](
            repeating: 0,
            count: Int(n)
        )

        vDSP_vfixu8(
            &clippedResult, 1,
            &outU8, 1,
            n
        )

        outU8.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                memcpy(
                    buf.data,
                    base,
