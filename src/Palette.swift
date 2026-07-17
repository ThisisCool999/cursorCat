import AppKit

enum Palette {
    static let ink = NSColor(hex: 0x2E2837)
    static let body = NSColor(hex: 0xC9C1B4)
    static let shade = NSColor(hex: 0xA79D8F)
    static let cream = NSColor(hex: 0xF3EBDC)
    static let pink = NSColor(hex: 0xEFADB5)
    static let nose = NSColor(hex: 0xD97F8E)
    static let stripe = NSColor(hex: 0x8C8274)
    static let white = NSColor(hex: 0xFFFFFF)
    static let highlight = NSColor(hex: 0xDAD3C6)
    static let fish = NSColor(hex: 0x7FA8C9)
    static let biscuit = NSColor(hex: 0xD9A45B)
    static let water = NSColor(hex: 0x8FC3D9)
    static let chocolate = NSColor(hex: 0x6B4A3A)
    static let lemon = NSColor(hex: 0xE8D26F)

    static let colors: [Character: NSColor] = [
        "K": ink,
        "B": body,
        "S": shade,
        "C": cream,
        "P": pink,
        "N": nose,
        "W": white,
        "T": stripe,
        "H": highlight,
        "F": fish,
        "O": biscuit,
        "U": water,
        "D": chocolate,
        "L": lemon,
    ]
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum SpriteRenderer {
    static func cgImage(grid: [String], flipH: Bool = false, flipV: Bool = false, colors: [Character: NSColor] = Palette.colors) -> CGImage {
        let height = grid.count
        let width = grid.map { $0.count }.max() ?? 1
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for (rowIndex, row) in grid.enumerated() {
            for (colIndex, ch) in row.enumerated() {
                guard let raw = colors[ch],
                      let color = raw.usingColorSpace(.sRGB) else { continue }
                let x = flipH ? width - 1 - colIndex : colIndex
                let y = flipV ? height - 1 - rowIndex : rowIndex
                let base = (y * width + x) * 4
                pixels[base] = UInt8(round(color.redComponent * 255))
                pixels[base + 1] = UInt8(round(color.greenComponent * 255))
                pixels[base + 2] = UInt8(round(color.blueComponent * 255))
                pixels[base + 3] = 255
            }
        }
        return pixels.withUnsafeMutableBytes { buffer -> CGImage in
            let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            return context.makeImage()!
        }
    }
}
