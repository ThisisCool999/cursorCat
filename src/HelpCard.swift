import AppKit

final class HelpCard {
    private let panel: NSPanel
    private var dismissWork: DispatchWorkItem?

    private static let text = """
    ~ what can mochi do? ~

    click him ....... pets & meows
    click his file .. opens it, right from his mouth
    drag him ........ carry & fling him (he splats)
    drop a file ..... he holds it; drag it out of his
                      mouth into any app or folder
    ⌥-drop a file ... he buries it in the Trash
    double-click .... fetch! type a name, he digs it up
    right-click ..... this menu

    treat box ....... your cursor becomes a snack —
                      hold it near him OR click him
                      with it to feed him directly
                      fish / biscuit / water = yum
                      chocolate / lemon = big mistake
                      (he gets full; wait a bit between)

    on his own he pounces on your cursor, naps ON your
    cursor, jumps onto your windows and rides them,
    climbs walls, hangs from the menu bar, sniffs new
    Desktop files, and digs up ones you forgot about.
    also: rainbow zoomies, post-drink water splashes,
    opinions about your apps, and sometimes he EATS
    YOUR CURSOR. he gives it back. usually.

    🐾 in the menu bar has everything + Quit

    (click this card to close it)
    """

    init() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: Palette.ink,
        ]
        let string = NSAttributedString(string: HelpCard.text, attributes: attrs)
        let textSize = string.boundingRect(
            with: NSSize(width: 460, height: 2000),
            options: [.usesLineFragmentOrigin]
        ).size
        let width = ceil(textSize.width) + 36
        let height = ceil(textSize.height) + 32

        let view = HelpCardView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.content = string
        panel = NSPanel(
            contentRect: view.frame,
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
        panel.contentView = view
        view.onClick = { [weak self] in
            self?.hide()
        }
    }

    func show(near frame: NSRect) {
        var origin = NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY + 10)
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            origin.x = max(visible.minX + 10, min(visible.maxX - panel.frame.width - 10, origin.x))
            origin.y = max(visible.minY + 10, min(visible.maxY - panel.frame.height - 10, origin.y))
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: work)
    }

    func hide() {
        dismissWork?.cancel()
        dismissWork = nil
        panel.orderOut(nil)
    }
}

private final class HelpCardView: NSView {
    var content: NSAttributedString?
    var onClick: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Palette.cream.setFill()
        bounds.fill()
        Palette.ink.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()
        content?.draw(
            with: NSRect(x: 18, y: 16, width: bounds.width - 36, height: bounds.height - 32),
            options: [.usesLineFragmentOrigin]
        )
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
