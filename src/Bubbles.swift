import AppKit
import QuartzCore

final class BubbleController {
    private let petPanel: NSPanel
    private var speechPanel: NSPanel?
    private var speechTimer: Timer?
    private var heartPanels: [NSPanel] = []
    private var fetchPanel: NSPanel?
    private var fetchField: NSTextField?
    private var fetchDelegate: FetchInputDelegate?
    private var fetchCallback: ((String?) -> Void)?

    init(petPanel: NSPanel) {
        self.petPanel = petPanel
    }

    var isFetchInputVisible: Bool {
        return fetchPanel != nil
    }

    func showSpeech(_ text: String, duration: TimeInterval) {
        removeSpeech()
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: Palette.ink,
            .paragraphStyle: paragraph
        ])
        let measured = attributed.boundingRect(
            with: NSSize(width: 240, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        )
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let textWidth = max(min(ceil(measured.width), 240), 8)
        let textHeight = min(ceil(measured.height), lineHeight * 3)
        let size = NSSize(
            width: max(textWidth + 20, 30),
            height: textHeight + 12 + BubbleBoxView.tailHeight
        )
        let panel = makeBubblePanel(size: size, interactive: false)
        let box = BubbleBoxView(frame: NSRect(origin: .zero, size: size))
        box.text = attributed
        panel.contentView = box
        panel.setFrameOrigin(bubbleOrigin(for: size))
        attachChild(panel)
        speechPanel = panel
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.fadeOutSpeech()
        }
        RunLoop.main.add(timer, forMode: .common)
        speechTimer = timer
    }

    func showHeart() {
        guard heartPanels.count < 6 else { return }
        let size = NSSize(width: 30, height: 30)
        let panel = makeBubblePanel(size: size, interactive: false)
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.addSubview(HeartPixelView(frame: NSRect(x: 3, y: 4, width: 24, height: 21)))
        panel.contentView = container
        let jitter = CGFloat.random(in: -20...20)
        let origin = NSPoint(
            x: (petPanel.frame.midX - size.width / 2 + jitter).rounded(),
            y: (petPanel.frame.maxY - 30).rounded()
        )
        panel.setFrameOrigin(origin)
        attachChild(panel)
        heartPanels.append(panel)
        animateFloat(panel, drift: NSPoint(x: 0, y: 36), duration: 0.9) { [weak self] finished in
            self?.heartPanels.removeAll { $0 === finished }
        }
    }

    func showZzz() {
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        let attributed = NSAttributedString(string: "z", attributes: [
            .font: font,
            .foregroundColor: Palette.ink
        ])
        let glyphSize = attributed.size()
        let size = NSSize(width: ceil(glyphSize.width) + 4, height: ceil(glyphSize.height) + 4)
        let panel = makeBubblePanel(size: size, interactive: false)
        let view = GlyphView(frame: NSRect(origin: .zero, size: size))
        view.glyph = attributed
        panel.contentView = view
        let origin = NSPoint(
            x: (petPanel.frame.midX - size.width / 2 + 6).rounded(),
            y: (petPanel.frame.maxY - 30).rounded()
        )
        panel.setFrameOrigin(origin)
        attachChild(panel)
        animateFloat(panel, drift: NSPoint(x: 10, y: 36), duration: 1.6, completion: nil)
    }

    func showFetchInput(onSubmit: @escaping (String?) -> Void) {
        hideFetchInput()
        fetchCallback = onSubmit
        let fieldWidth: CGFloat = 220
        let fieldHeight: CGFloat = 19
        let size = NSSize(
            width: fieldWidth + 20,
            height: fieldHeight + 12 + BubbleBoxView.tailHeight
        )
        let panel = makeBubblePanel(size: size, interactive: true)
        let box = BubbleBoxView(frame: NSRect(origin: .zero, size: size))
        let field = NSTextField(frame: NSRect(
            x: 10,
            y: BubbleBoxView.tailHeight + 6,
            width: fieldWidth,
            height: fieldHeight
        ))
        field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        field.focusRingType = .none
        field.drawsBackground = false
        field.isBordered = false
        field.isBezeled = false
        field.textColor = Palette.ink
        field.placeholderString = "fetch me something…"
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        let delegate = FetchInputDelegate { [weak self] result in
            self?.finishFetch(result)
        }
        field.delegate = delegate
        panel.delegate = delegate
        box.addSubview(field)
        panel.contentView = box
        panel.setFrameOrigin(bubbleOrigin(for: size))
        attachChild(panel)
        fetchPanel = panel
        fetchField = field
        fetchDelegate = delegate
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    func hideFetchInput() {
        finishFetch(nil)
    }

    private func finishFetch(_ result: String?) {
        guard let callback = fetchCallback, let panel = fetchPanel else { return }
        fetchCallback = nil
        fetchPanel = nil
        fetchField = nil
        panel.delegate = nil
        fetchDelegate = nil
        detachAndHide(panel)
        callback(result)
    }

    private func fadeOutSpeech() {
        guard let panel = speechPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self, self.speechPanel === panel else { return }
            self.removeSpeech()
        })
    }

    private func removeSpeech() {
        speechTimer?.invalidate()
        speechTimer = nil
        guard let panel = speechPanel else { return }
        speechPanel = nil
        detachAndHide(panel)
    }

    private func animateFloat(
        _ panel: NSPanel,
        drift: NSPoint,
        duration: TimeInterval,
        completion: ((NSPanel) -> Void)?
    ) {
        var target = panel.frame
        target.origin.x += drift.x
        target.origin.y += drift.y
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: false)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.detachAndHide(panel)
            completion?(panel)
        })
    }

    private func detachAndHide(_ panel: NSPanel) {
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func attachChild(_ panel: NSPanel) {
        petPanel.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
    }

    private func bubbleOrigin(for size: NSSize) -> NSPoint {
        let parent = petPanel.frame
        var origin = NSPoint(x: parent.midX - size.width / 2, y: parent.maxY + 2)
        let screen = petPanel.screen ?? NSScreen.main ?? NSScreen.screens.first
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), max(visible.maxX - size.width, visible.minX))
            origin.y = min(max(origin.y, visible.minY), max(visible.maxY - size.height, visible.minY))
        }
        return NSPoint(x: origin.x.rounded(), y: origin.y.rounded())
    }

    private func makeBubblePanel(size: NSSize, interactive: Bool) -> NSPanel {
        let rect = NSRect(origin: .zero, size: size)
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel: NSPanel
        if interactive {
            panel = KeyCapablePanel(contentRect: rect, styleMask: style, backing: .buffered, defer: false)
        } else {
            panel = NSPanel(contentRect: rect, styleMask: style, backing: .buffered, defer: false)
        }
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = !interactive
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = petPanel.level
        panel.collectionBehavior = petPanel.collectionBehavior
        return panel
    }
}

private final class KeyCapablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

private final class FetchInputDelegate: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    private let handler: (String?) -> Void

    init(handler: @escaping (String?) -> Void) {
        self.handler = handler
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let trimmed = control.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                handler(trimmed)
            }
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            handler(nil)
            return true
        }
        return false
    }

    func windowDidResignKey(_ notification: Notification) {
        handler(nil)
    }
}

private final class BubbleBoxView: NSView {
    static let tailHeight: CGFloat = 6
    var text: NSAttributedString?

    override func draw(_ dirtyRect: NSRect) {
        let tail = BubbleBoxView.tailHeight
        let body = NSRect(x: 0, y: tail, width: bounds.width, height: bounds.height - tail)
        Palette.cream.setFill()
        body.fill()
        Palette.ink.setStroke()
        let border = NSBezierPath(rect: body.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()
        let midX = (bounds.width / 2).rounded()
        let outerTail = NSBezierPath()
        outerTail.move(to: NSPoint(x: midX - 5, y: tail))
        outerTail.line(to: NSPoint(x: midX + 5, y: tail))
        outerTail.line(to: NSPoint(x: midX, y: 0))
        outerTail.close()
        Palette.ink.setFill()
        outerTail.fill()
        let innerTail = NSBezierPath()
        innerTail.move(to: NSPoint(x: midX - 3, y: tail + 2))
        innerTail.line(to: NSPoint(x: midX + 3, y: tail + 2))
        innerTail.line(to: NSPoint(x: midX, y: 2))
        innerTail.close()
        Palette.cream.setFill()
        innerTail.fill()
        if let text = text {
            let textRect = NSRect(
                x: 10,
                y: tail + 6,
                width: bounds.width - 20,
                height: bounds.height - tail - 12
            )
            text.draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }
}

private final class HeartPixelView: NSView {
    private static let grid = [
        ".##..##.",
        "#oo##oo#",
        "#oooooo#",
        "#oooooo#",
        ".#oooo#.",
        "..#oo#..",
        "...##..."
    ]

    override func draw(_ dirtyRect: NSRect) {
        let scale: CGFloat = 3
        let rows = HeartPixelView.grid
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, cell) in row.enumerated() {
                let fill: NSColor
                switch cell {
                case "#":
                    fill = Palette.ink
                case "o":
                    fill = Palette.nose
                default:
                    continue
                }
                fill.setFill()
                NSRect(
                    x: CGFloat(columnIndex) * scale,
                    y: CGFloat(rows.count - 1 - rowIndex) * scale,
                    width: scale,
                    height: scale
                ).fill()
            }
        }
    }
}

private final class GlyphView: NSView {
    var glyph: NSAttributedString?

    override func draw(_ dirtyRect: NSRect) {
        guard let glyph = glyph else { return }
        let size = glyph.size()
        glyph.draw(at: NSPoint(
            x: ((bounds.width - size.width) / 2).rounded(),
            y: ((bounds.height - size.height) / 2).rounded()
        ))
    }
}
