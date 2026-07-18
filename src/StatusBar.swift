import AppKit

final class StatusBarController: NSObject {
    private let actions: MenuActions
    private let statusItem: NSStatusItem
    private let statusMenu = NSMenu()
    private var menuRefresher: MenuRefresher?
    private var isSleeping = false
    private var isStayPut = false
    private var heldFileName: String?

    init(actions: MenuActions) {
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.title = "🐾"
        let refresher = MenuRefresher { [weak self] menu in
            self?.populate(menu)
        }
        menuRefresher = refresher
        statusMenu.delegate = refresher
        statusItem.menu = statusMenu
    }

    func update(isSleeping: Bool, isStayPut: Bool, heldFileName: String?) {
        self.isSleeping = isSleeping
        self.isStayPut = isStayPut
        self.heldFileName = heldFileName
    }

    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        populate(menu)
        return menu
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(ClosureMenuItem(title: "Fetch a File…", handler: actions.fetch))
        menu.addItem(ClosureMenuItem(title: "Grab Finder Selection", handler: actions.grabFinderSelection))
        menu.addItem(ClosureMenuItem(title: "Treat Box…", handler: actions.showTreatBox))
        let catsItem = NSMenuItem(title: "Cats", action: nil, keyEquivalent: "")
        catsItem.submenu = actions.buildCatsMenu()
        menu.addItem(catsItem)
        menu.addItem(NSMenuItem.separator())
        if let name = heldFileName {
            let holdingItem = NSMenuItem(title: "Holding: \(middleTruncated(name, maxLength: 40))", action: nil, keyEquivalent: "")
            holdingItem.isEnabled = false
            menu.addItem(holdingItem)
            menu.addItem(ClosureMenuItem(title: "Open It", handler: actions.openHeldFile))
            menu.addItem(ClosureMenuItem(title: "Reveal in Finder", handler: actions.revealHeldFile))
            menu.addItem(ClosureMenuItem(title: "Put It Down", handler: actions.dropHeldFile))
            menu.addItem(NSMenuItem.separator())
        }
        menu.addItem(ClosureMenuItem(title: isSleeping ? "Everyone Wake Up" : "Everyone Sleep", handler: actions.toggleSleep))
        let stayPutItem = ClosureMenuItem(title: "Everyone Stay Put", handler: actions.toggleStayPut)
        stayPutItem.state = isStayPut ? .on : .off
        menu.addItem(stayPutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(ClosureMenuItem(title: "Summon Cats", handler: actions.summon))
        menu.addItem(ClosureMenuItem(title: "What Can CursorCat Do?", handler: actions.showHelp))
        menu.addItem(ClosureMenuItem(title: "Quit CursorCat", keyEquivalent: "q", handler: actions.quit))
    }

    private func middleTruncated(_ name: String, maxLength: Int) -> String {
        guard name.count > maxLength else { return name }
        let keptCount = maxLength - 1
        let headCount = keptCount - keptCount / 2
        let tailCount = keptCount / 2
        return String(name.prefix(headCount)) + "…" + String(name.suffix(tailCount))
    }
}

private final class MenuRefresher: NSObject, NSMenuDelegate {
    private let refresh: (NSMenu) -> Void

    init(refresh: @escaping (NSMenu) -> Void) {
        self.refresh = refresh
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh(menu)
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError()
    }

    @objc private func invoke() {
        handler()
    }
}
