import AppKit
import UniformTypeIdentifiers

let canvasW = 640
let canvasH = 360
let fps = 12.0
let duration = 24.0
let frameCount = Int(duration * fps)
let groundY: CGFloat = 26
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "demo.gif"

let grey = CatLook.coat(Coat.by(id: "grey"))
let orange = CatLook.coat(Coat.by(id: "orange"))
let walkCycle = ["walk1", "walk2", "walk3", "walk2"]

func lerp(_ a: CGFloat, _ b: CGFloat, _ t0: Double, _ t1: Double, _ t: Double) -> CGFloat {
    let k = max(0, min(1, (t - t0) / (t1 - t0)))
    return a + (b - a) * CGFloat(k)
}

func lerpP(_ a: CGPoint, _ b: CGPoint, _ t0: Double, _ t1: Double, _ t: Double) -> CGPoint {
    CGPoint(x: lerp(a.x, b.x, t0, t1, t), y: lerp(a.y, b.y, t0, t1, t))
}

let rainbowColors = [0xE05B5B, 0xE0A35B, 0xE8D26F, 0x7DBF6E, 0x6E9DBF, 0xA07DBF].map { NSColor(hex: $0) }

func drawBackground(_ ctx: CGContext) {
    let sky = NSColor(hex: 0x8FA8C0).usingColorSpace(.sRGB)!
    ctx.setFillColor(sky.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
    let deep = NSColor(hex: 0x7A93AC).usingColorSpace(.sRGB)!
    ctx.setFillColor(deep.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasW, height: 120))

    let bar = NSColor(hex: 0xF2EFE9).usingColorSpace(.sRGB)!
    ctx.setFillColor(bar.cgColor)
    ctx.fill(CGRect(x: 0, y: canvasH - 22, width: canvasW, height: 22))
    NSString(string: "🐾  Mochi").draw(
        at: NSPoint(x: 10, y: CGFloat(canvasH) - 19),
        withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold), .foregroundColor: Palette.ink]
    )
    NSString(string: "3:07 PM").draw(
        at: NSPoint(x: CGFloat(canvasW) - 60, y: CGFloat(canvasH) - 19),
        withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: Palette.ink]
    )

    let winRect = CGRect(x: 390, y: 140, width: 210, height: 150)
    ctx.setFillColor(NSColor(hex: 0xF7F4EE).usingColorSpace(.sRGB)!.cgColor)
    ctx.fill(winRect)
    ctx.setFillColor(NSColor(hex: 0xE3DFD6).usingColorSpace(.sRGB)!.cgColor)
    ctx.fill(CGRect(x: 390, y: 268, width: 210, height: 22))
    let lights = [0xE0645C, 0xE0A835, 0x6BB550]
    for (i, hex) in lights.enumerated() {
        ctx.setFillColor(NSColor(hex: hex).usingColorSpace(.sRGB)!.cgColor)
        ctx.fillEllipse(in: CGRect(x: 398 + CGFloat(i) * 14, y: 274, width: 9, height: 9))
    }
    ctx.setFillColor(NSColor(hex: 0xD8D3C8).usingColorSpace(.sRGB)!.cgColor)
    for row in 0..<5 {
        ctx.fill(CGRect(x: 402, y: 240 - row * 20, width: row % 2 == 0 ? 180 : 140, height: 8))
    }
    ctx.setStrokeColor(Palette.ink.withAlphaComponent(0.25).cgColor)
    ctx.stroke(winRect.insetBy(dx: -0.5, dy: -0.5), width: 1)
}

func drawCat(_ ctx: CGContext, look: CatLook, key: String, feetX: CGFloat, feetY: CGFloat, flipH: Bool, shadow: Bool = true) {
    if shadow {
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.15).cgColor)
        ctx.fillEllipse(in: CGRect(x: feetX - 30, y: feetY - 5, width: 60, height: 9))
    }
    let img = Sprites.cg(look: look, key: key, flipH: flipH)
    ctx.interpolationQuality = .none
    ctx.draw(img, in: CGRect(x: feetX - 48, y: feetY, width: 96, height: 96))
}

func drawBubble(_ ctx: CGContext, _ text: String, cx: CGFloat, bottomY: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
        .foregroundColor: Palette.ink,
    ]
    let size = NSString(string: text).size(withAttributes: attrs)
    let w = size.width + 16
    let h = size.height + 10
    var x = cx - w / 2
    x = max(6, min(CGFloat(canvasW) - w - 6, x))
    let rect = CGRect(x: x, y: bottomY, width: w, height: h)
    ctx.setFillColor(Palette.cream.usingColorSpace(.sRGB)!.cgColor)
    ctx.fill(rect)
    ctx.setStrokeColor(Palette.ink.usingColorSpace(.sRGB)!.cgColor)
    ctx.stroke(rect, width: 2)
    ctx.setFillColor(Palette.cream.usingColorSpace(.sRGB)!.cgColor)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx - 5, y: bottomY))
    ctx.addLine(to: CGPoint(x: cx + 5, y: bottomY))
    ctx.addLine(to: CGPoint(x: cx, y: bottomY - 6))
    ctx.closePath()
    ctx.fillPath()
    NSString(string: text).draw(at: NSPoint(x: x + 8, y: bottomY + 5), withAttributes: attrs)
}

func drawHeart(_ ctx: CGContext, x: CGFloat, y: CGFloat, alpha: CGFloat) {
    let color = Palette.nose.usingColorSpace(.sRGB)!.withAlphaComponent(alpha)
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: x - 5, y: y, width: 6, height: 6))
    ctx.fillEllipse(in: CGRect(x: x - 1, y: y, width: 6, height: 6))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: x - 5, y: y + 2))
    ctx.addLine(to: CGPoint(x: x + 5, y: y + 2))
    ctx.addLine(to: CGPoint(x: x, y: y - 6))
    ctx.closePath()
    ctx.fillPath()
}

func drawTongue(_ ctx: CGContext, from: CGPoint, to: CGPoint) {
    ctx.setLineCap(.round)
    ctx.setStrokeColor(Palette.ink.usingColorSpace(.sRGB)!.cgColor)
    ctx.setLineWidth(11)
    ctx.beginPath(); ctx.move(to: from); ctx.addLine(to: to); ctx.strokePath()
    ctx.setStrokeColor(Palette.nose.usingColorSpace(.sRGB)!.cgColor)
    ctx.setLineWidth(7)
    ctx.beginPath(); ctx.move(to: from); ctx.addLine(to: to); ctx.strokePath()
    ctx.setFillColor(Palette.nose.usingColorSpace(.sRGB)!.cgColor)
    ctx.fillEllipse(in: CGRect(x: to.x - 7, y: to.y - 7, width: 14, height: 14))
    ctx.setStrokeColor(Palette.ink.usingColorSpace(.sRGB)!.cgColor)
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: to.x - 7, y: to.y - 7, width: 14, height: 14))
}

let arrowImage = NSCursor.arrow.image

func drawCursor(_ ctx: CGContext, at p: CGPoint, alpha: CGFloat = 1) {
    guard let cg = arrowImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.draw(cg, in: CGRect(x: p.x, y: p.y - 22, width: 16, height: 22))
    ctx.restoreGState()
}

func drawDoc(_ ctx: CGContext, x: CGFloat, y: CGFloat) {
    let rect = CGRect(x: x - 10, y: y - 13, width: 20, height: 26)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(rect)
    ctx.setStrokeColor(Palette.ink.usingColorSpace(.sRGB)!.cgColor)
    ctx.stroke(rect, width: 2)
    ctx.setFillColor(NSColor(hex: 0x8FA8C0).usingColorSpace(.sRGB)!.cgColor)
    for row in 0..<3 {
        ctx.fill(CGRect(x: x - 6, y: y + 4 - CGFloat(row) * 6, width: 12, height: 2))
    }
}

func drawFish(_ ctx: CGContext, at p: CGPoint) {
    ctx.interpolationQuality = .none
    ctx.draw(TreatArt.cg(.fish), in: CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32))
}

var rainbowTrail: [(x: CGFloat, y: CGFloat, born: Double)] = []

let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outPath) as CFURL, UTType.gif.identifier as CFString, frameCount, nil
)!
CGImageDestinationSetProperties(dest, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
] as CFDictionary)

for frame in 0..<frameCount {
    let t = Double(frame) / fps

    let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: canvasW, pixelsHigh: canvasH,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: bmp)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext

    drawBackground(ctx)

    var catX: CGFloat = 200
    var catKey = "sit1"
    var catFlip = false
    let mouth = { CGPoint(x: catX + 10, y: groundY + 46) }
    let cursorHome = CGPoint(x: 330, y: 130)

    switch t {
    case ..<2.5:
        catX = lerp(-60, 200, 0, 2.5, t)
        catKey = walkCycle[Int(t * 6) % 4]
    case ..<3.2:
        catKey = "sit1"
    case ..<4.0:
        catKey = "tongueOut"
    case ..<4.5:
        catKey = "tongueOut"
    case ..<7.3:
        catKey = "chew"
    case ..<7.8:
        catKey = "tongueOut"
    case ..<8.4:
        catKey = "sit1"
    case ..<10.0:
        catX = lerp(200, 600, 8.4, 10.0, t)
        catKey = walkCycle[Int(t * 11) % 4]
    case ..<11.6:
        catX = lerp(600, 160, 10.0, 11.6, t)
        catKey = walkCycle[Int(t * 11) % 4]
        catFlip = true
    case ..<12.4:
        catX = 160
        catKey = Int(t * 3) % 2 == 0 ? "sit1" : "blink"
    case ..<14.4:
        catX = lerp(160, 470, 12.4, 14.4, t)
        catKey = walkCycle[Int(t * 8) % 4]
    case ..<16.4:
        catX = 470
        catKey = Int(t * 5) % 2 == 0 ? "dig1" : "dig2"
    case ..<17.2:
        catX = 470
        catKey = "sit2"
    case ..<18.0:
        catX = lerp(470, 300, 17.2, 18.0, t)
        catKey = walkCycle[Int(t * 8) % 4]
        catFlip = true
    default:
        catX = 300
        catKey = "hold"
    }

    if t >= 8.4, t < 11.6 {
        if frame % 1 == 0 {
            rainbowTrail.append((catX + (t < 10.0 ? -34 : 34), groundY + 12, t))
        }
    }
    rainbowTrail.removeAll { t - $0.born > 1.3 }
    for chunk in rainbowTrail {
        let age = t - chunk.born
        let alpha = age > 0.7 ? CGFloat(1 - (age - 0.7) / 0.6) : 1
        ctx.saveGState()
        ctx.setAlpha(alpha)
        for (i, color) in rainbowColors.enumerated() {
            ctx.setFillColor(color.usingColorSpace(.sRGB)!.cgColor)
            ctx.fill(CGRect(x: chunk.x - 9, y: chunk.y - CGFloat(age) * 10 + CGFloat(i) * 3, width: 18, height: 3))
        }
        ctx.restoreGState()
    }

    drawCat(ctx, look: grey, key: catKey, feetX: catX, feetY: groundY, flipH: catFlip)

    if t >= 20.0 {
        let friendX = lerp(700, 400, 20.0, 22.0, t)
        let friendKey = t < 22.0 ? walkCycle[Int(t * 6) % 4] : (Int(t * 3) % 2 == 0 ? "sit1" : "sit2")
        drawCat(ctx, look: orange, key: friendKey, feetX: friendX, feetY: groundY, flipH: true)
        if t >= 22.2 {
            drawBubble(ctx, "a friend :3", cx: 400, bottomY: groundY + 100)
        }
    }

    switch t {
    case 3.2..<4.0:
        drawCursor(ctx, at: lerpP(CGPoint(x: 620, y: 200), cursorHome, 3.2, 4.0, t))
    case 4.0..<4.5:
        let tip = lerpP(mouth(), cursorHome, 4.0, 4.35, min(t, 4.35))
        drawTongue(ctx, from: mouth(), to: t < 4.35 ? tip : lerpP(cursorHome, mouth(), 4.35, 4.5, t))
        drawCursor(ctx, at: cursorHome, alpha: t < 4.35 ? 1 : 0)
        if t >= 4.35 {
            drawCursor(ctx, at: lerpP(cursorHome, mouth(), 4.35, 4.5, t))
        }
    case 4.5..<7.3:
        drawBubble(ctx, "*GULP* got ur cursor", cx: catX, bottomY: groundY + 100)
    case 7.3..<7.8:
        drawCursor(ctx, at: lerpP(mouth(), cursorHome, 7.3, 7.7, t))
        drawBubble(ctx, "ptooey!!", cx: catX, bottomY: groundY + 100)
    case 12.0..<16.4:
        let fishPos = CGPoint(x: 470, y: lerp(200, groundY + 40, 12.0, 12.6, t))
        if t < 14.4 {
            drawFish(ctx, at: fishPos)
            drawCursor(ctx, at: CGPoint(x: fishPos.x + 6, y: fishPos.y + 18))
        } else if t < 15.4 {
            drawFish(ctx, at: CGPoint(x: 470, y: groundY + 40))
        }
        if t >= 14.4 {
            drawBubble(ctx, "nom nom nom!!", cx: 470, bottomY: groundY + 100)
            for h in 0..<2 {
                let hy = groundY + 90 + CGFloat((t - 14.4) * 30) + CGFloat(h * 14)
                drawHeart(ctx, x: 470 + CGFloat(h * 16 - 8), y: hy, alpha: CGFloat(max(0, 1 - (t - 14.4) / 2)))
            }
        }
    case 17.2..<24.0:
        if t < 18.0 {
            drawDoc(ctx, x: 300, y: lerp(320, groundY + 30, 17.2, 18.0, t))
        } else {
            drawDoc(ctx, x: catX + 16, y: groundY + 34)
            if t < 20.6 {
                drawBubble(ctx, "got it: homework.pdf", cx: catX, bottomY: groundY + 100)
            }
        }
    default:
        break
    }

    NSGraphicsContext.restoreGraphicsState()

    let cg = bmp.cgImage!
    CGImageDestinationAddImage(dest, cg, [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 1.0 / fps,
            kCGImagePropertyGIFUnclampedDelayTime: 1.0 / fps,
        ],
    ] as CFDictionary)
}

if CGImageDestinationFinalize(dest) {
    print("wrote \(outPath) — \(frameCount) frames @ \(Int(fps))fps")
} else {
    print("FAILED to write gif")
    exit(1)
}
