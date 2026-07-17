import AppKit

final class Cat {
    let engine = PetEngine()
    let panel = PetPanel()
    let view: PetView
    let bubbles: BubbleController
    var look: CatLook
    let isGuest: Bool
    var spec: CatSpec?

    var lastHidden = false
    var rainbowAccumulator: TimeInterval = 0
    var guestLeaveAt: CFTimeInterval = 0

    var onHeldChanged: (() -> Void)?

    var heldFile: URL? {
        didSet {
            view.heldFileURL = heldFile
            engine.isHoldingFile = heldFile != nil
            if heldFile == nil {
                engine.stopOffering()
            }
            onHeldChanged?()
        }
    }

    init(look: CatLook, isGuest: Bool) {
        self.look = look
        self.isGuest = isGuest
        self.view = PetView(frame: NSRect(x: 0, y: 0, width: PetEngine.panelSize, height: PetEngine.panelSize))
        self.view.look = look
        self.panel.contentView = view
        self.bubbles = BubbleController(petPanel: panel)
    }

    func setLook(_ look: CatLook) {
        self.look = look
        view.look = look
    }

    func place(on screen: NSRect, at x: CGFloat? = nil) {
        engine.placeAtStart(screen: screen)
        panel.setFrameOrigin(NSPoint(x: (x ?? screen.midX) - PetEngine.panelSize / 2, y: screen.maxY - 260))
        panel.orderFrontRegardless()
    }

    func teardown() {
        bubbles.hideFetchInput()
        panel.orderOut(nil)
    }
}
