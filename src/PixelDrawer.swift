import AppKit

private final class PixelDrawerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class PixelDrawerCanvasView: NSView {
    let cellSize: CGFloat = 16
    var toolChar: Character? = "B"
    var onGridChanged: (() -> Void)?

    private var template: [[Character]] = []
    private var cells: [[Character]] = []
    private var colorMap: [Character: NSColor] = Palette.colors

    private let checkerLight = NSColor(white: 0.93, alpha: 1)
    private let checkerDark = NSColor(white: 0.88, alpha: 1)
    private let gridLineColor = NSColor(white: 0, alpha: 0.08)
    private let borderColor = NSColor(white: 0, alpha: 0.2)

    override var isFlipped: Bool { true }

    func load(template: [[Character]], colorMap: [Character: NSColor]) {
        self.template = template
        self.cells = template
        self.colorMap = colorMap
        needsDisplay = true
    }

    func gridRows() -> [String] {
        cells.map { String($0) }
    }

    override func draw(_ dirtyRect: NSRect) {
        for row in 0..<cells.count {
            for col in 0..<cells[row].count {
                let rect = NSRect(
                    x: CGFloat(col) * cellSize,
                    y: CGFloat(row) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                let ch = cells[row][col]
                if ch == "." {
                    let light = (row + col) % 2 == 0
                    (light ? checkerLight : checkerDark).setFill()
                    rect.fill()
                } else if let color = colorMap[ch] {
                    color.setFill()
                    rect.fill()
                }
            }
        }
        gridLineColor.setFill()
        for line in 1..<32 {
            let offset = CGFloat(line) * cellSize
            NSRect(x: offset - 0.5, y: 0, width: 1, height: bounds.height).fill()
            NSRect(x: 0, y: offset - 0.5, width: bounds.width, height: 1).fill()
        }
        borderColor.setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }

    override func mouseDown(with event: NSEvent) {
        applyBrush(at: convert(event.locationInWindow, from: nil), erasing: false)
    }

    override func mouseDragged(with event: NSEvent) {
        applyBrush(at: convert(event.locationInWindow, from: nil), erasing: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        applyBrush(at: convert(event.locationInWindow, from: nil), erasing: true)
    }

    override func rightMouseDragged(with event: NSEvent) {
        applyBrush(at: convert(event.locationInWindow, from: nil), erasing: true)
    }

    private func applyBrush(at point: NSPoint, erasing: Bool) {
        let col = Int(floor(point.x / cellSize))
        let row = Int(floor(point.y / cellSize))
        guard row >= 0, row < cells.count, col >= 0, col < cells[row].count else { return }
        let templateChar = template[row][col]
        guard templateChar != "K", templateChar != "." else { return }
        let newChar = erasing ? templateChar : (toolChar ?? templateChar)
        guard cells[row][col] != newChar else { return }
        cells[row][col] = newChar
        setNeedsDisplay(NSRect(
            x: CGFloat(col) * cellSize,
            y: CGFloat(row) * cellSize,
            width: cellSize,
            height: cellSize
        ))
        onGridChanged?()
    }
}

private final class PixelDrawerPreviewView: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = image, let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        context.draw(image, in: bounds)
    }
}

private final class PixelDrawerToolRowView: NSView {
    let title: String
    var color: NSColor? {
        didSet { needsDisplay = true }
    }
    var isSelected = false {
        didSet { needsDisplay = true }
    }
    var onClick: (() -> Void)?

    init(title: String, frame: NSRect) {
        self.title = title
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
        let swatchRect = NSRect(x: 8, y: (bounds.height - 16) / 2, width: 16, height: 16)
        if let color = color {
            color.setFill()
            NSBezierPath(roundedRect: swatchRect, xRadius: 3, yRadius: 3).fill()
        } else {
            for i in 0..<2 {
                for j in 0..<2 {
                    let light = (i + j) % 2 == 0
                    (light ? NSColor(white: 0.95, alpha: 1) : NSColor(white: 0.75, alpha: 1)).setFill()
                    NSRect(
                        x: swatchRect.minX + CGFloat(i) * 8,
                        y: swatchRect.minY + CGFloat(j) * 8,
                        width: 8,
                        height: 8
                    ).fill()
                }
            }
        }
        NSColor.black.withAlphaComponent(0.2).setStroke()
        NSBezierPath(roundedRect: swatchRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3).stroke()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        (title as NSString).draw(
            at: NSPoint(x: swatchRect.maxX + 8, y: (bounds.height - 15) / 2),
            withAttributes: attributes
        )
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

final class PixelDrawer: NSObject, NSWindowDelegate {
    var onSave: ((_ name: String, _ baseCoatId: String, _ grid: [String]) -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    private var panel: NSPanel?
    private var canvas: PixelDrawerCanvasView!
    private var preview: PixelDrawerPreviewView!
    private var nameField: NSTextField!
    private var toolRows: [PixelDrawerToolRowView] = []
    private var coat = Coat.all[0]

    private static let toolSpecs: [(title: String, char: Character?)] = [
        ("Fur", "B"),
        ("Dark", "S"),
        ("Light", "H"),
        ("Marking", "T"),
        ("Belly", "C"),
        ("Ear", "P"),
        ("Nose", "N"),
        ("Erase", nil),
    ]

    private static let templateRows: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "..........K...........K........",
        ".........KPK.........KPK.......",
        "........KPPPK.......KPPPK.......",
        "........KBBBKKKKKKKKKBBBK.......",
        ".......KBHHHHHHHBBBBBBBBBK......",
        ".......KBHHHBBBBBBBBBBBBBK......",
        ".......KBBBBBBBBBBBBBBBBBK......",
        ".......KBBBKKBBBBBBBKKBBBK......",
        ".......KBBBKKBBBBBBBKKBBBK......",
        ".......KBBBBBCCNNCCCBBBBBK......",
        ".......KBBBBBCKCCCKCBBBBBK......",
        ".......KBBBBBCCCCCCCBBBBBK......",
        ".......KSSSBBBBBBBBBBBSSSK......",
        "........KBBBBBBBBBBBBBBBK.......",
        "..........KBBBBBBBBBBBK........",
        ".........KBBBBBBBBBBBBBK.......",
        "........KBBBBBBBBBBBBBBK.......",
        ".......KBBBBBBBBBBBBBBBK.......",
        ".......KBBBBBBBBBBBBBBBK.......",
        ".......KBBBBBBBBBBBBBSSK.......",
        ".......KBBBBBBBBBBBBBSSK.......",
        ".......KBBBBBBBBBBKBBBBK.......",
        ".......KBBBBBBBBBBKBBBBK.......",
        "..KKKK.KBBBBBBBBBBKBBBBK.......",
        ".KBTBTBKBBBBBBBBBKCCCCCK.......",
        ".KBTBTBKBBBBBBBBBKCCCCCK.......",
        ".KKKKKKKKKKKKKKKKKKKKKKK.......",
    ]

    private static let template: [[Character]] = templateRows.map { row in
        var chars = Array(row)
        if chars.count > 32 {
            chars.removeLast(chars.count - 32)
        }
        while chars.count < 32 {
            chars.append(".")
        }
        return chars
    }

    func show(baseCoat: Coat) {
        coat = baseCoat
        let panel = ensurePanel()
        canvas.load(template: Self.template, colorMap: baseCoat.colorMap)
        nameField.stringValue = "My Cat"
        for (index, row) in toolRows.enumerated() {
            if let char = Self.toolSpecs[index].char {
                row.color = baseCoat.colorMap[char]
            } else {
                row.color = nil
            }
        }
        selectTool(index: 0)
        refreshPreview()
        centerOnPrimaryScreen(panel)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }
        let contentSize = NSSize(width: 768, height: 568)
        let newPanel = PixelDrawerPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "Draw Your Cat"
        newPanel.titlebarAppearsTransparent = true
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.isMovableByWindowBackground = true
        newPanel.delegate = self

        let content = NSView(frame: NSRect(origin: .zero, size: contentSize))

        let canvasView = PixelDrawerCanvasView(frame: NSRect(x: 16, y: 16, width: 512, height: 512))
        canvasView.onGridChanged = { [weak self] in
            self?.refreshPreview()
        }
        content.addSubview(canvasView)
        canvas = canvasView

        let previewView = PixelDrawerPreviewView(frame: NSRect(x: 600, y: 432, width: 96, height: 96))
        content.addSubview(previewView)
        preview = previewView

        toolRows = []
        for (index, spec) in Self.toolSpecs.enumerated() {
            let rowFrame = NSRect(x: 544, y: 392 - CGFloat(index) * 28, width: 208, height: 26)
            let row = PixelDrawerToolRowView(title: spec.title, frame: rowFrame)
            row.onClick = { [weak self] in
                self?.selectTool(index: index)
            }
            content.addSubview(row)
            toolRows.append(row)
        }

        let field = NSTextField(string: "My Cat")
        field.frame = NSRect(x: 544, y: 62, width: 208, height: 24)
        field.placeholderString = "Name"
        field.font = NSFont.systemFont(ofSize: 13)
        content.addSubview(field)
        nameField = field

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.frame = NSRect(x: 544, y: 20, width: 100, height: 30)
        content.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 652, y: 20, width: 100, height: 30)
        content.addSubview(saveButton)

        newPanel.contentView = content
        newPanel.setContentSize(contentSize)
        panel = newPanel
        return newPanel
    }

    private func selectTool(index: Int) {
        for (rowIndex, row) in toolRows.enumerated() {
            row.isSelected = rowIndex == index
        }
        canvas.toolChar = Self.toolSpecs[index].char
    }

    private func refreshPreview() {
        preview.image = SpriteRenderer.cgImage(grid: canvas.gridRows(), colors: coat.colorMap)
    }

    private func centerOnPrimaryScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.screens.first else { return }
        let frame = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: screen.frame.midX - frame.width / 2,
            y: screen.frame.midY - frame.height / 2
        ))
    }

    @objc private func saveTapped() {
        let trimmed = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "My Cat" : trimmed
        let grid = canvas.gridRows()
        let coatId = coat.id
        if Thread.isMainThread {
            onSave?(name, coatId, grid)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onSave?(name, coatId, grid)
            }
        }
        hide()
    }

    @objc private func cancelTapped() {
        hide()
    }
}
