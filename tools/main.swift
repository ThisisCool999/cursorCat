import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "sheet.png"
let scale = 8
let cell = Sprites.size * scale
let labelHeight = 24
let columns = 4

var allGrids = Sprites.frames
for (kind, grid) in TreatArt.grids {
    allGrids["treat-\(kind.rawValue)"] = grid
}
allGrids["mini-sleep"] = TreatArt.miniSleep1

var problems: [String] = []
for (key, grid) in allGrids.sorted(by: { $0.key < $1.key }) {
    if grid.count != Sprites.size {
        problems.append("\(key): \(grid.count) rows")
    }
    for (i, row) in grid.enumerated() where row.count != Sprites.size {
        problems.append("\(key) row \(i): \(row.count) chars")
    }
    for (i, row) in grid.enumerated() {
        for ch in row where ch != "." && Palette.colors[ch] == nil {
            problems.append("\(key) row \(i): unknown char \(ch)")
        }
    }
}
for p in problems {
    print("WARN \(p)")
}

let keys = allGrids.keys.sorted()
let rows = (keys.count + columns - 1) / columns
let width = columns * (cell + 16) + 16
let height = rows * (cell + labelHeight + 16) + 16

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
let gc = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = gc
let ctx = gc.cgContext

NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
NSColor(white: 0.93, alpha: 1).setFill()
for cy in stride(from: 0, to: height, by: 16) {
    for cx in stride(from: 0, to: width, by: 16) where ((cx / 16) + (cy / 16)) % 2 == 0 {
        NSRect(x: cx, y: cy, width: 16, height: 16).fill()
    }
}

ctx.interpolationQuality = .none
let labelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
    .foregroundColor: NSColor.black,
]

for (i, key) in keys.enumerated() {
    let col = i % columns
    let row = i / columns
    let x = 16 + col * (cell + 16)
    let yTop = 16 + row * (cell + labelHeight + 16)
    let yFlipped = height - yTop - cell - labelHeight
    let image = SpriteRenderer.cgImage(grid: allGrids[key]!)
    ctx.draw(image, in: CGRect(x: x, y: yFlipped + labelHeight, width: cell, height: cell))
    NSString(string: key).draw(at: NSPoint(x: x, y: yFlipped), withAttributes: labelAttrs)
}

NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(width)x\(height)) frames: \(keys.joined(separator: ", "))")
