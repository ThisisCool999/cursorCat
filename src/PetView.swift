import AppKit

final class PetView: NSView, NSDraggingSource {
    var look: CatLook = .coat(Coat.all[0])
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    var onCatDragBegan: ((CGPoint) -> Void)?
    var onCatDragMoved: ((CGPoint) -> Void)?
    var onCatDragEnded: ((CGPoint) -> Void)?
    var onFileDropped: ((URL, Bool) -> Void)?
    var onFileDraggedAway: (() -> Void)?
    var onHeldIconClick: (() -> Void)?

    var heldFileURL: URL? {
        didSet {
            if let url = heldFileURL {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 34, height: 34)
                iconLayer.contents = icon
            } else {
                iconLayer.contents = nil
                iconLayer.isHidden = true
            }
        }
    }

    private let shadowLayer = CALayer()
    private let spriteLayer = CALayer()
    private let iconLayer = CALayer()
    private var heldIconCenter: CGPoint?

    private enum DragMode {
        case none
        case cat
        case file
    }

    private var pressPoint: NSPoint?
    private var pressEvent: NSEvent?
    private var pressOnIcon = false
    private var dragMode = DragMode.none

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        shadowLayer.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        shadowLayer.bounds = CGRect(x: 0, y: 0, width: 20 * PetEngine.scale, height: 2.6 * PetEngine.scale)
        shadowLayer.cornerRadius = 1.3 * PetEngine.scale
        shadowLayer.position = CGPoint(x: PetEngine.panelSize / 2, y: PetEngine.inset + 1.4 * PetEngine.scale)
        shadowLayer.isHidden = true
        layer?.addSublayer(shadowLayer)

        spriteLayer.frame = CGRect(
            x: PetEngine.inset, y: PetEngine.inset,
            width: 32 * PetEngine.scale, height: 32 * PetEngine.scale
        )
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.minificationFilter = .nearest
        layer?.addSublayer(spriteLayer)

        iconLayer.bounds = CGRect(x: 0, y: 0, width: 34, height: 34)
        iconLayer.contentsGravity = .resizeAspect
        iconLayer.isHidden = true
        layer?.addSublayer(iconLayer)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func apply(_ state: RenderState) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.contents = Sprites.cg(
            look: look,
            key: state.frameKey,
            flipH: state.flipH,
            flipV: state.flipV,
            rotation: state.rotation
        )
        shadowLayer.isHidden = !state.showShadow
        heldIconCenter = state.heldIconCenter
        if let center = state.heldIconCenter, heldFileURL != nil {
            iconLayer.position = center
            iconLayer.isHidden = false
        } else {
            iconLayer.isHidden = true
        }
        CATransaction.commit()
    }

    func debugIconState() -> String {
        "hidden=\(iconLayer.isHidden) center=\(heldIconCenter.map { "(\(Int($0.x)),\(Int($0.y)))" } ?? "nil") contents=\(iconLayer.contents != nil)"
    }

    private func iconHitRect() -> CGRect? {
        guard heldFileURL != nil, let center = heldIconCenter else { return nil }
        return CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)
    }

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        pressPoint = local
        pressEvent = event
        pressOnIcon = iconHitRect()?.contains(local) ?? false
        dragMode = .none
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressPoint else { return }
        let local = convert(event.locationInWindow, from: nil)
        if dragMode == .none {
            let moved = hypot(local.x - start.x, local.y - start.y)
            guard moved > 4 else { return }
            if pressOnIcon {
                dragMode = .file
                beginFileDrag()
            } else {
                dragMode = .cat
                onCatDragBegan?(NSEvent.mouseLocation)
            }
        }
        if dragMode == .cat {
            onCatDragMoved?(NSEvent.mouseLocation)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            pressPoint = nil
            pressEvent = nil
            dragMode = .none
        }
        if dragMode == .cat {
            onCatDragEnded?(NSEvent.mouseLocation)
            return
        }
        if dragMode == .file {
            return
        }
        if pressOnIcon {
            onHeldIconClick?()
        } else if event.clickCount == 2 {
            onDoubleTap?()
        } else {
            onTap?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    private func beginFileDrag() {
        guard let url = heldFileURL, let event = pressEvent else { return }
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 34, height: 34)
        let center = heldIconCenter ?? CGPoint(x: bounds.midX, y: bounds.midY)
        item.setDraggingFrame(
            CGRect(x: center.x - 17, y: center.y - 17, width: 34, height: 34),
            contents: icon
        )
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            onFileDraggedAway?()
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canRead = sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return canRead ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        guard let url = urls?.first else { return false }
        onFileDropped?(url, false)
        return true
    }
}
