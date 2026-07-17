import AppKit

final class TreatBox {
    var onPick: ((TreatKind?) -> Void)?
    var onClosed: (() -> Void)?
    var isVisible: Bool { panel.isVisible }

    private let panel: NSPanel
    private let boxView: TreatBoxView
    private let cell: CGFloat = 46
    private let pad: CGFloat = 10

    init() {
        let kinds = TreatKind.allCases
        let width = pad * 2 + CGFloat(kinds.count + 1) * 46
        let height = 46 + 20 + 16
        boxView = TreatBoxView(frame: NSRect(x: 0, y: 0, width: width, height: CGFloat(height)))
        panel = NSPanel(
            contentRect: boxView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.contentView = boxView
        boxView.onPick = { [weak self] kind in
            self?.onPick?(kind)
        }
        boxView.onClose = { [weak self] in
            self?.hide()
        }
    }

    func toggle(near frame: NSRect, selected: TreatKind?) {
        if panel.isVisible {
            hide()
        } else {
            show(near: frame, selected: selected)
        }
    }

    func show(near frame: NSRect, selected: TreatKind?) {
        boxView.selected = selected
        boxView.needsDisplay = true
        var origin = NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY + 8)
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            origin.x = max(visible.minX + 8, min(visible.maxX - panel.frame.width - 8, origin.x))
            origin.y = max(visible.minY + 8, min(visible.maxY - panel.frame.height - 8, origin.y))
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        onClosed?()
    }

    func refresh(selected: TreatKind?) {
        boxView.selected = selected
        boxView.needsDisplay = true
    }
}

private final class TreatBoxView: NSView {
    var selected: TreatKind?
    var onPick: ((TreatKind?) -> Void)?
    var onClose: (() -> Void)?

    private let kinds = TreatKind.allCases
    private let cell: CGFloat = 46
    private let pad: CGFloat = 10

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func cellRect(_ index: Int) -> NSRect {
        NSRect(x: pad + CGFloat(index) * cell, y: 12, width: cell, height: cell)
    }

    override func draw(_ dirtyRect: NSRect) {
        Palette.cream.setFill()
        bounds.fill()
        Palette.ink.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()

        let title = "treats for your cursor  (click again to put back)"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
            .foregroundColor: Palette.ink,
        ]
        NSString(string: title).draw(at: NSPoint(x: pad, y: bounds.height - 16), withAttributes: titleAttrs)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.interpolationQuality = .none
        for (index, kind) in kinds.enumerated() {
            let rect = cellRect(index)
            if kind == selected {
                Palette.pink.withAlphaComponent(0.55).setFill()
                rect.insetBy(dx: 3, dy: 3).fill()
                Palette.ink.setStroke()
                let ring = NSBezierPath(rect: rect.insetBy(dx: 3, dy: 3))
                ring.lineWidth = 2
                ring.stroke()
            }
            ctx.draw(TreatArt.cg(kind), in: rect.insetBy(dx: 7, dy: 7))
        }
        let closeRect = cellRect(kinds.count)
        let closeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .bold),
            .foregroundColor: Palette.ink,
        ]
        NSString(string: "✕").draw(
            at: NSPoint(x: closeRect.midX - 6, y: closeRect.midY - 10),
            withAttributes: closeAttrs
        )
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, kind) in kinds.enumerated() where cellRect(index).contains(point) {
            let next = kind == selected ? nil : kind
            selected = next
            needsDisplay = true
            onPick?(next)
            return
        }
        if cellRect(kinds.count).contains(point) {
            onClose?()
        }
    }
}
