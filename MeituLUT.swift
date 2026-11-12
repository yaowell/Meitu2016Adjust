import Foundation


public final class MeituLUT {

public static let shared = MeituLUT()

private static let brightnessRows = 301
private static let contrastRows = 151
private static let brightnessBase = -150
private static let contrastBase = -50

private var bri: [UInt8]?
private var con: [UInt8]?

private init() {}

// MARK: - 加载 LUT

public func load(bundle: Bundle = .main) throws {
    guard let b = bundle.url(
        forResource: "brightness_301x256",
        withExtension: "bin"
    ),
    let c = bundle.url(
        forResource: "contrast_151x256",
        withExtension: "bin"
    ) else {
        throw LUTError.resourceMissing
    }

    bri = try Self.readTable(b, rows: Self.brightnessRows)
    con = try Self.readTable(c, rows: Self.contrastRows)
}

public func load(
    brightness: Data,
    contrast: Data
) throws {
    bri = try Self.decode(
        brightness,
        rows: Self.brightnessRows
    )

    con = try Self.decode(
        contrast,
        rows: Self.contrastRows
    )
}

public enum LUTError: Error {
    case resourceMissing
    case badLength
}

private static func readTable(
    _ url: URL,
    rows: Int
) throws -> [UInt8] {
    try decode(Data(contentsOf: url), rows: rows)
}

private static func decode(
    _ data: Data,
    rows: Int
) throws -> [UInt8] {
    guard data.count == rows * 256 else {
        throw LUTError.badLength
    }

    return [UInt8](data)
}

// MARK: - 滑杆转换为 LUT 索引

public static func brightnessIndex(_ slider: Float) -> Int {
    Int(
        (0.5 + 1.5 * slider)
            .rounded(.toNearestOrEven)
    )
}

public static func contrastIndex(_ slider: Float) -> Int {
    slider >= 0
        ? Int(slider.rounded(.toNearestOrEven))
        : Int(
            (0.5 + 0.5 * slider)
                .rounded(.toNearestOrEven)
        )
}

// MARK: - 获取 LUT

public func brightnessTable(slider: Float) -> [Float] {
    table(
        bri,
        rows: Self.brightnessRows,
        filterIndex: Self.brightnessIndex(slider) + 150
    )
}

public func contrastTable(slider: Float) -> [Float] {
    table(
        con,
        rows: Self.contrastRows,
        filterIndex: Self.contrastIndex(slider) + 50
    )
}

public func brightnessTableU8(slider: Float) -> [UInt8] {
    tableU8(
        bri,
        rows: Self.brightnessRows,
        filterIndex: Self.brightnessIndex(slider) + 150
    )
}

public func contrastTableU8(slider: Float) -> [UInt8] {
    tableU8(
        con,
        rows: Self.contrastRows,
        filterIndex: Self.contrastIndex(slider) + 50
    )
}

// MARK: - 表数据处理

private func tableU8(
    _ source: [UInt8]?,
    rows: Int,
    filterIndex: Int
) -> [UInt8] {
    let identity = (0..<256).map { UInt8($0) }

    guard let source,
          filterIndex >= 0,
          filterIndex < rows else {
        return identity
    }

    let start = filterIndex * 256

    return Array(
        source[start..<(start + 256)]
    )
}

private func table(
    _ source: [UInt8]?,
    rows: Int,
    filterIndex: Int
) -> [Float] {
    tableU8(
        source,
        rows: rows,
        filterIndex: filterIndex
    ).map {
        Float($0) / 255.0
    }
}

}