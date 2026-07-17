import AppKit

final class CursorCompanion {
    enum Mode: Equatable {
        case none
        case treat(TreatKind)
        case sleepingCat
    }

    var mode = Mode.none {
        didSet {
            guard mode != oldValue else { return }
            apply()
        }
    }
    var napLook: CatLook = .coat(Coat.all[0])

    private let panel: NSPanel
    private let spriteLayer = CALayer()
    private var smoothed = CGPoint.zero
    private var animClock: TimeInterval = 0
    private var lastMiniFrame = -1
    private let side: CGFloat = 48

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: side, height: side),
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

        let view = NSView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        view.wantsLayer = true
        spriteLayer.frame = view.bounds
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.minificationFilter = .nearest
        view.layer?.addSublayer(spriteLayer)
        panel.contentView = view
    }

    func update(cursor: CGPoint, dt: TimeInterval) {
        guard mode != .none else { return }
        animClock += dt
        let target = CGPoint(x: cursor.x + 6, y: cursor.y - side + 6)
        let blend = min(1, dt * 16)
        smoothed = CGPoint(
            x: smoothed.x + (target.x - smoothed.x) * blend,
            y: smoothed.y + (target.y - smoothed.y) * blend
        )
        panel.setFrameOrigin(smoothed)
        if case .sleepingCat = mode {
            let frame = Int(animClock * 1.2) % 2
            if frame != lastMiniFrame {
                lastMiniFrame = frame
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                spriteLayer.contents = TreatArt.miniSleep(frame, look: napLook)
                CATransaction.commit()
            }
        }
    }

    private func apply() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        switch mode {
        case .none:
            panel.orderOut(nil)
        case .treat(let kind):
            spriteLayer.contents = TreatArt.cg(kind)
            snapToCursor()
            panel.orderFrontRegardless()
        case .sleepingCat:
            lastMiniFrame = -1
            spriteLayer.contents = TreatArt.miniSleep(0, look: napLook)
            snapToCursor()
            panel.orderFrontRegardless()
        }
        CATransaction.commit()
    }

    private func snapToCursor() {
        let cursor = NSEvent.mouseLocation
        smoothed = CGPoint(x: cursor.x + 6, y: cursor.y - side + 6)
        panel.setFrameOrigin(smoothed)
    }
}
