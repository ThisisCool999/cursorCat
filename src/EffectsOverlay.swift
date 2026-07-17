import AppKit

final class EffectsOverlay {
    private let panel: NSPanel
    private let root = CALayer()
    private let tongueOutline = CAShapeLayer()
    private let tongueFill = CAShapeLayer()
    private let tongueTip = CALayer()
    private let fakeCursorLayer = CALayer()

    private struct Particle {
        let layer: CALayer
        var velocity: CGVector
        var age: TimeInterval
        let life: TimeInterval
        let sliding: Bool
    }

    private var particles: [Particle] = []
    private let rainbowImage: CGImage

    init() {
        let frame = NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.addSublayer(root)
        panel.contentView = view

        rainbowImage = EffectsOverlay.makeRainbowChunk()

        tongueOutline.strokeColor = Palette.ink.cgColor
        tongueOutline.fillColor = nil
        tongueOutline.lineWidth = 13
        tongueOutline.lineCap = .round
        tongueFill.strokeColor = Palette.nose.cgColor
        tongueFill.fillColor = nil
        tongueFill.lineWidth = 8
        tongueFill.lineCap = .round
        tongueTip.backgroundColor = Palette.nose.cgColor
        tongueTip.borderColor = Palette.ink.cgColor
        tongueTip.borderWidth = 2
        tongueTip.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
        tongueTip.cornerRadius = 8
        let cursorImage = NSCursor.arrow.image
        fakeCursorLayer.contents = cursorImage
        fakeCursorLayer.bounds = CGRect(origin: .zero, size: cursorImage.size)
        for layer in [tongueOutline, tongueFill, tongueTip, fakeCursorLayer] {
            layer.isHidden = true
            root.addSublayer(layer)
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    private static func makeRainbowChunk() -> CGImage {
        let colors: [NSColor] = [
            NSColor(hex: 0xE05B5B), NSColor(hex: 0xE0A35B), NSColor(hex: 0xE8D26F),
            NSColor(hex: 0x7DBF6E), NSColor(hex: 0x6E9DBF), NSColor(hex: 0xA07DBF),
        ]
        let width = 18
        let stripe = 3
        let height = colors.count * stripe
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for (index, color) in colors.enumerated() {
            let srgb = color.usingColorSpace(.sRGB)!
            context.setFillColor(srgb.cgColor)
            context.fill(CGRect(x: 0, y: index * stripe, width: width, height: stripe))
        }
        return context.makeImage()!
    }

    func spawnRainbowChunk(at point: CGPoint) {
        let layer = CALayer()
        layer.contents = rainbowImage
        layer.magnificationFilter = .nearest
        layer.bounds = CGRect(x: 0, y: 0, width: 18, height: 18)
        layer.position = CGPoint(x: point.x + .random(in: -3...3), y: point.y + .random(in: -2...4))
        addParticle(layer, velocity: CGVector(dx: 0, dy: -10), life: 1.3, sliding: false)
    }

    func spawnWaterSplash(at point: CGPoint) {
        for _ in 0..<8 {
            let layer = CALayer()
            layer.backgroundColor = Palette.water.cgColor
            layer.borderColor = Palette.ink.withAlphaComponent(0.4).cgColor
            layer.borderWidth = 1
            let size = CGFloat.random(in: 5...9)
            layer.bounds = CGRect(x: 0, y: 0, width: size, height: size * 1.3)
            layer.cornerRadius = size / 2
            layer.position = point
            let velocity = CGVector(dx: .random(in: -170...170), dy: .random(in: 60...260))
            addParticle(layer, velocity: velocity, life: 3.6, sliding: true)
        }
    }

    private func addParticle(_ layer: CALayer, velocity: CGVector, life: TimeInterval, sliding: Bool) {
        if particles.count > 60 {
            particles.first?.layer.removeFromSuperlayer()
            particles.removeFirst()
        }
        root.addSublayer(layer)
        particles.append(Particle(layer: layer, velocity: velocity, age: 0, life: life, sliding: sliding))
    }

    func setTongue(from: CGPoint?, to: CGPoint?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let from, let to else {
            tongueOutline.isHidden = true
            tongueFill.isHidden = true
            tongueTip.isHidden = true
            return
        }
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        tongueOutline.path = path
        tongueFill.path = path
        tongueTip.position = to
        tongueOutline.isHidden = false
        tongueFill.isHidden = false
        tongueTip.isHidden = false
    }

    func setFakeCursor(at point: CGPoint?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let point else {
            fakeCursorLayer.isHidden = true
            return
        }
        fakeCursorLayer.position = CGPoint(
            x: point.x + fakeCursorLayer.bounds.width / 2 - 4,
            y: point.y - fakeCursorLayer.bounds.height / 2 + 4
        )
        fakeCursorLayer.isHidden = false
    }

    func debugTongueState() -> String {
        "fillHidden=\(tongueFill.isHidden) hasPath=\(tongueFill.path != nil) panelVisible=\(panel.isVisible) panelAlpha=\(panel.alphaValue)"
    }

    func tick(_ dt: TimeInterval) {
        guard !particles.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var kept: [Particle] = []
        for var particle in particles {
            particle.age += dt
            if particle.age >= particle.life {
                particle.layer.removeFromSuperlayer()
                continue
            }
            if particle.sliding {
                if particle.age < 0.5 {
                    particle.velocity.dy -= 900 * dt
                    particle.velocity.dx *= (1 - 2.5 * dt)
                } else {
                    particle.velocity = CGVector(dx: 0, dy: -22)
                }
            }
            let position = particle.layer.position
            particle.layer.position = CGPoint(
                x: position.x + particle.velocity.dx * dt,
                y: position.y + particle.velocity.dy * dt
            )
            let remaining = particle.life - particle.age
            particle.layer.opacity = remaining < 1 ? Float(remaining) : 1
            kept.append(particle)
        }
        particles = kept
        CATransaction.commit()
    }
}
