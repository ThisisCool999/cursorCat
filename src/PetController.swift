import AppKit

private typealias CGSConnectionID = UInt32

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ cid: CGSConnectionID, _ target: CGSConnectionID, _ key: CFString, _ value: CFTypeRef) -> CGError

final class ClosureItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, enabled: Bool = true, state: NSControl.StateValue = .off, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        isEnabled = enabled
        self.state = state
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler() }
}

final class PetController: NSObject {
    private var cats: [Cat] = []
    let tracker = WindowTracker()
    let fetcher = SpotlightFetcher()
    let finder = FinderBridge()
    let watcher = DesktopWatcher()
    let companion = CursorCompanion()
    let treatBox = TreatBox()
    let helpCard = HelpCard()
    let effects = EffectsOverlay()
    let pixelDrawer = PixelDrawer()

    var contextMenuProvider: (() -> NSMenu)?
    var onStateChanged: (() -> Void)?

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastCursor = NSPoint.zero
    private var cursorSpeed: CGFloat = 0
    private var lastZzz: CFTimeInterval = 0
    private var lastSleepState = false
    private var lastAppQuip: CFTimeInterval = 0
    private var lastGuestCheck: CFTimeInterval = 0
    private var appObserver: Any?
    private var gagCursorHidden = false
    private var nappingCat: Cat?
    private var napClickMonitor: Any?
    private var napTimeoutWork: DispatchWorkItem?
    private var debugLastDump: CFTimeInterval = 0
    private var lastSpaceCheck: CFTimeInterval = 0
    private let debugPath = NSTemporaryDirectory() + "mochi_state.txt"

    private var primary: Cat? { cats.first { !$0.isGuest } }
    private var heldOwner: Cat? { cats.first { $0.heldFile != nil } }
    var heldFile: URL? { heldOwner?.heldFile }

    private(set) var selectedTreat: TreatKind? {
        didSet {
            companion.mode = (nappingCat != nil) ? companion.mode : (selectedTreat.map { .treat($0) } ?? .none)
            treatBox.refresh(selected: selectedTreat)
        }
    }

    override init() {
        super.init()
        treatBox.onPick = { [weak self] kind in
            self?.selectedTreat = kind
        }
        pixelDrawer.onSave = { [weak self] name, coatId, grid in
            self?.addCat(spec: CatSpec(name: name, coatId: coatId, customGrid: grid))
        }
        tracker.ownWindowNumbers = { [weak self] in
            guard let self else { return [] }
            return Set(self.cats.map { CGWindowID($0.panel.windowNumber) })
        }
        for spec in CatStore.load() {
            makeCat(look: spec.look, isGuest: false, spec: spec)
        }
    }

    func start() {
        let connection = _CGSDefaultConnection()
        _ = CGSSetConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        effects.show()
        let screen = primaryScreen().frame
        for (index, cat) in cats.enumerated() {
            let x = screen.midX + CGFloat(index - cats.count / 2) * 140
            cat.place(on: screen, at: x)
        }
        tracker.start()
        watchApps()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                _ = try? FileManager.default.contentsOfDirectory(atPath: desktop.path)
            }
            DispatchQueue.main.async { self?.watcher.start() }
        }
        wireWatcher()
        if ProcessInfo.processInfo.environment["MOCHI_TEST_HOLD"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.primary?.heldFile = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
            }
        }
        if ProcessInfo.processInfo.environment["MOCHI_TEST_TONGUE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, let cat = self.cats.last else { return }
                cat.engine.debugTongueEat(cursor: NSEvent.mouseLocation)
            }
        }
        guard let anchor = cats.first?.view else { return }
        let link = anchor.displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func primaryScreen() -> NSScreen {
        NSScreen.screens.first ?? NSScreen.main!
    }

    @discardableResult
    private func makeCat(look: CatLook, isGuest: Bool, spec: CatSpec?) -> Cat {
        let cat = Cat(look: look, isGuest: isGuest)
        cat.spec = spec
        cat.onHeldChanged = { [weak self] in self?.onStateChanged?() }
        wireCat(cat)
        cats.append(cat)
        return cat
    }

    @objc private func step(_ link: CADisplayLink) {
        let dt: TimeInterval
        if lastTimestamp == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(max(link.timestamp - lastTimestamp, 0.001), 0.05)
        }
        lastTimestamp = link.timestamp

        let screen = primaryScreen()
        let frame = screen.frame
        let cursor = NSEvent.mouseLocation
        let cursorDelta = hypot(cursor.x - lastCursor.x, cursor.y - lastCursor.y)
        cursorSpeed = cursorSpeed * 0.8 + (cursorDelta / CGFloat(dt)) * 0.2
        lastCursor = cursor

        var notch: ClosedRange<CGFloat>?
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           left.maxX < right.minX {
            notch = left.maxX...right.minX
        }

        let env = PetEnvironment(
            groundY: frame.minY, ceilingY: frame.maxY,
            leftWallX: frame.minX, rightWallX: frame.maxX,
            platforms: tracker.platforms, cursor: cursor,
            cursorSpeed: cursorSpeed, notchRange: notch, treat: selectedTreat
        )

        let scale = screen.backingScaleFactor
        var tongueState: RenderState?

        for cat in cats {
            let state = cat.engine.tick(dt, env: env)
            if cat.engine.activity == .tongueEat, tongueState == nil {
                tongueState = state
            }

            if state.hidden != cat.lastHidden {
                cat.lastHidden = state.hidden
                cat.panel.alphaValue = state.hidden ? 0 : 1
                cat.panel.ignoresMouseEvents = state.hidden
            }
            let rounded = NSPoint(
                x: round(state.panelOrigin.x * scale) / scale,
                y: round(state.panelOrigin.y * scale) / scale
            )
            if cat.panel.frame.origin != rounded {
                cat.panel.setFrameOrigin(rounded)
            }
            cat.view.apply(state)

            if cat.engine.activity == .run, cat.engine.rainbowRun {
                cat.rainbowAccumulator += dt
                if cat.rainbowAccumulator > 0.06 {
                    cat.rainbowAccumulator = 0
                    effects.spawnRainbowChunk(at: CGPoint(
                        x: cat.engine.position.x - cat.engine.facingDirection * 30,
                        y: cat.engine.position.y + 12
                    ))
                }
            }

            if !cat.panel.frame.intersects(frame), !cat.lastHidden {
                cat.place(on: frame)
            }
        }
        effects.setTongue(from: tongueState?.tongueFrom, to: tongueState?.tongueTo)
        effects.setFakeCursor(at: tongueState?.fakeCursor)
        if gagCursorHidden, tongueState == nil {
            gagCursorHidden = false
            CGDisplayShowCursor(CGMainDisplayID())
        }

        companion.update(cursor: cursor, dt: dt)
        effects.tick(dt)
        maybeManageGuests(link.timestamp, screen: frame)

        if link.timestamp - lastSpaceCheck > 2 {
            lastSpaceCheck = link.timestamp
            let strandedCat = cats.contains { !$0.lastHidden && (!$0.panel.isVisible || !$0.panel.isOnActiveSpace) }
            if strandedCat || !effects.isOnActiveSpace {
                effects.show()
                for cat in cats where !cat.lastHidden {
                    cat.panel.orderFrontRegardless()
                }
            }
        }

        if let primary, primary.engine.activity == .sleep, link.timestamp - lastZzz > 4 {
            lastZzz = link.timestamp
            primary.bubbles.showZzz()
        }
        if let primary, primary.engine.activity == .idle, Double.random(in: 0...1) < dt / 75 {
            primary.bubbles.showSpeech(
                ["mrrp", "...", ":3", "*stretches*", "*flicks tail*", "mew"].randomElement()!,
                duration: 1.4
            )
        }
        let sleeping = primary?.engine.isSleeping ?? false
        if sleeping != lastSleepState {
            lastSleepState = sleeping
            onStateChanged?()
        }

        if ProcessInfo.processInfo.environment["MOCHI_DEBUG"] == "1", link.timestamp - debugLastDump > 1, let primary {
            debugLastDump = link.timestamp
            let tongueCat = cats.first { $0.engine.activity == .tongueEat }
            let line = "cats=\(cats.count) activity=\(primary.engine.activity) tongueOwner=\(tongueCat != nil) overlay=[\(effects.debugTongueState())]\n"
            if let data = line.data(using: .utf8), let handle = FileHandle(forWritingAtPath: debugPath) {
                handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
            } else {
                try? line.write(toFile: debugPath, atomically: true, encoding: .utf8)
            }
        }
    }

    private func wireCat(_ cat: Cat) {
        cat.engine.onPounce = { [weak cat] in cat?.bubbles.showHeart() }
        cat.engine.onTreatReaction = { [weak self, weak cat] kind in
            guard let self, let cat else { return }
            switch kind {
            case .fish:
                cat.bubbles.showSpeech("nom nom nom!!", duration: 2.0); self.showHearts(cat, 3)
            case .biscuit:
                cat.bubbles.showSpeech("crunch crunch", duration: 2.0); self.showHearts(cat, 2)
            case .water:
                cat.bubbles.showSpeech("lap lap lap~", duration: 2.0); self.showHearts(cat, 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self, weak cat] in
                    guard let self, let cat else { return }
                    self.effects.spawnWaterSplash(at: CGPoint(x: cat.engine.position.x, y: cat.engine.position.y + 50))
                    cat.bubbles.showSpeech("*shakes head* SPLASH", duration: 1.6)
                }
            case .chocolate:
                cat.bubbles.showSpeech("BLEH!! chocolate is TOXIC for cats!!", duration: 2.6)
            case .lemon:
                cat.bubbles.showSpeech("HISSS!! citrus?!", duration: 2.2)
            }
            if !kind.isBad, self.selectedTreat == kind {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self, self.selectedTreat == kind else { return }
                    self.selectedTreat = nil
                }
            }
        }
        cat.engine.onEnterCursorNap = { [weak self, weak cat] in
            guard let self, let cat else { return }
            self.beginCursorNap(cat)
        }
        cat.engine.onCursorEaten = { [weak self, weak cat] in
            guard let self, let cat else { return }
            if !self.gagCursorHidden {
                self.gagCursorHidden = true
                CGDisplayHideCursor(CGMainDisplayID())
            }
            cat.bubbles.showSpeech("*GULP* got ur cursor", duration: 2.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak cat] in
                guard let cat, cat.engine.activity == .tongueEat else { return }
                cat.bubbles.showSpeech("*munch munch*", duration: 1.4)
            }
        }
        cat.engine.onCursorSpat = { [weak cat] in cat?.bubbles.showSpeech("ptooey!!", duration: 1.6) }
        cat.engine.tongueGate = { [weak self] in
            self?.cats.allSatisfy { $0.engine.activity != .tongueEat } ?? true
        }

        cat.view.onTap = { [weak self, weak cat] in
            guard let self, let cat else { return }
            cat.engine.noteInteraction()
            if let kind = self.selectedTreat {
                if !cat.engine.feedNow(kind) {
                    cat.bubbles.showSpeech("*sniff* …not hungry rn", duration: 1.6)
                }
                return
            }
            cat.bubbles.showHeart()
            if Double.random(in: 0...1) < 0.3 {
                cat.bubbles.showSpeech(["mrrp", "meow", "prrrr", ":3"].randomElement()!, duration: 1.2)
            }
        }
        cat.view.onDoubleTap = { [weak self, weak cat] in
            guard let self, let cat, !cat.isGuest else { return }
            self.promptFetch(cat)
        }
        cat.view.onHeldIconClick = { [weak self, weak cat] in
            guard let self, let cat else { return }
            self.openHeld(cat)
        }
        cat.view.onRightClick = { [weak self, weak cat] event in
            guard let self, let cat else { return }
            NSMenu.popUpContextMenu(self.buildCatContextMenu(for: cat), with: event, for: cat.view)
        }
        cat.view.onCatDragBegan = { [weak cat] point in cat?.engine.beginDrag(at: point) }
        cat.view.onCatDragMoved = { [weak cat] point in cat?.engine.dragMoved(to: point) }
        cat.view.onCatDragEnded = { [weak cat] point in cat?.engine.endDrag(at: point) }
        cat.view.onFileDropped = { [weak cat] url, _ in
            guard let cat else { return }
            cat.engine.noteInteraction()
            cat.heldFile = url
            cat.engine.surprise()
            cat.bubbles.showSpeech("got it: \(url.lastPathComponent)", duration: 2.0)
        }
        cat.view.onFileDraggedAway = { [weak cat] in
            guard let cat else { return }
            cat.heldFile = nil
            cat.bubbles.showSpeech("delivered!", duration: 1.4)
        }
    }

    private func showHearts(_ cat: Cat, _ count: Int) {
        for index in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.25) { [weak cat] in
                cat?.bubbles.showHeart()
            }
        }
    }

    private func beginCursorNap(_ cat: Cat) {
        guard nappingCat == nil else { return }
        nappingCat = cat
        companion.napLook = cat.look
        companion.mode = .sleepingCat
        onStateChanged?()
        napClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.endCursorNap()
        }
        let work = DispatchWorkItem { [weak self] in self?.endCursorNap() }
        napTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int.random(in: 40...90)), execute: work)
    }

    private func endCursorNap() {
        guard let cat = nappingCat else { return }
        if let monitor = napClickMonitor { NSEvent.removeMonitor(monitor); napClickMonitor = nil }
        napTimeoutWork?.cancel(); napTimeoutWork = nil
        cat.engine.wakeFromCursorNap(at: NSEvent.mouseLocation)
        nappingCat = nil
        companion.mode = selectedTreat.map { .treat($0) } ?? .none
        onStateChanged?()
    }

    private func maybeManageGuests(_ now: CFTimeInterval, screen: NSRect) {
        for cat in cats where cat.isGuest {
            if now > cat.guestLeaveAt {
                cat.guestLeaveAt = .greatestFiniteMagnitude
                cat.bubbles.showSpeech("gotta go!", duration: 1.4)
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 1.0
                    cat.panel.animator().alphaValue = 0
                }, completionHandler: { [weak self, weak cat] in
                    guard let self, let cat else { return }
                    cat.teardown()
                    self.cats.removeAll { $0 === cat }
                })
            }
        }
        if lastGuestCheck == 0 { lastGuestCheck = now; return }
        guard now - lastGuestCheck > 45 else { return }
        lastGuestCheck = now
        let guestCount = cats.filter { $0.isGuest }.count
        guard guestCount < 2, cats.count < 6, Double.random(in: 0...1) < 0.15 else { return }
        summonGuest(screen: screen, now: now)
    }

    private func summonGuest(screen: NSRect, now: CFTimeInterval) {
        let coat = Coat.all.randomElement()!
        let cat = makeCat(look: .guest(coat), isGuest: true, spec: nil)
        cat.guestLeaveAt = now + .random(in: 35...75)
        cat.place(on: screen, at: .random(in: screen.minX + 100...screen.maxX - 100))
        cat.bubbles.showSpeech(["hi!", "a friend :3", "sup"].randomElement()!, duration: 1.8)
    }

    private func wireWatcher() {
        watcher.onNewFiles = { [weak self] urls in
            guard let self, let cat = self.primary, let url = urls.first, !cat.engine.isSleeping else { return }
            let screen = self.primaryScreen().frame
            let x = CGFloat.random(in: screen.midX - 300...screen.midX + 300)
            cat.engine.goInvestigate(x: x) { [weak cat] in
                cat?.bubbles.showSpeech("ooh, \(url.lastPathComponent)", duration: 2.2)
            }
        }
    }

    private func watchApps() {
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let cat = self.primary, !cat.engine.isSleeping else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != getpid(), let name = app.localizedName else { return }
            let now = CACurrentMediaTime()
            guard now - self.lastAppQuip > 90, Double.random(in: 0...1) < 0.35 else { return }
            self.lastAppQuip = now
            let lower = name.lowercased()
            let line: String
            if ["safari", "chrome", "arc", "firefox", "edge"].contains(where: lower.contains) {
                line = ["cat videos?", "whatcha browsing :3"].randomElement()!
            } else if ["xcode", "terminal", "iterm", "code", "cursor"].contains(where: lower.contains) {
                line = ["beep boop", "compiling? nap time", "i could write swift"].randomElement()!
            } else if lower.contains("finder") {
                line = "MY territory."
            } else if ["music", "spotify"].contains(where: lower.contains) {
                line = "play jazz for cats"
            } else {
                line = ["*judges \(name)*", "\(name) again?", "*supervises*"].randomElement()!
            }
            cat.bubbles.showSpeech(line, duration: 2.0)
        }
    }

    func promptFetch(_ cat: Cat? = nil) {
        guard let target = cat ?? primary, !target.bubbles.isFetchInputVisible else { return }
        target.engine.noteInteraction()
        target.bubbles.showFetchInput { [weak self, weak target] query in
            guard let self, let target, let query, !query.isEmpty else { return }
            target.bubbles.showSpeech("hunting…", duration: 1.2)
            self.fetcher.fetch(query) { [weak target] url in
                guard let target else { return }
                if let url {
                    target.engine.goDig(at: nil) { [weak target] in
                        guard let target else { return }
                        target.heldFile = url
                        target.bubbles.showSpeech(url.lastPathComponent, duration: 2.6)
                    }
                } else {
                    target.bubbles.showSpeech("no luck :(", duration: 1.8)
                }
            }
        }
    }

    func grabFinderSelection() {
        guard let cat = primary else { return }
        cat.engine.noteInteraction()
        finder.selectedFiles { [weak cat] urls in
            guard let cat else { return }
            guard let url = urls.first else {
                cat.bubbles.showSpeech("select something in Finder first", duration: 2.2)
                return
            }
            cat.engine.goDig(at: nil) { [weak cat] in
                guard let cat else { return }
                cat.heldFile = url
                cat.bubbles.showSpeech(url.lastPathComponent, duration: 2.4)
            }
        }
    }

    private func openHeld(_ cat: Cat) {
        guard let url = cat.heldFile else { return }
        cat.engine.noteInteraction()
        finder.openFile(url)
        cat.bubbles.showSpeech("opening!", duration: 1.2)
    }

    func putDownHeldFile() { heldOwner?.heldFile = nil }
    func revealHeldFile() { if let url = heldOwner?.heldFile { finder.revealInFinder(url) } }
    func openHeldFile() { if let cat = heldOwner { openHeld(cat) } }

    func toggleTreatBox() {
        primary?.engine.noteInteraction()
        treatBox.toggle(near: primary?.panel.frame ?? .zero, selected: selectedTreat)
    }

    func showHelp() { helpCard.show(near: primary?.panel.frame ?? primaryScreen().frame) }

    func summon() {
        endCursorNap()
        let screen = primaryScreen().frame
        for cat in cats where !cat.isGuest {
            cat.lastHidden = false
            cat.panel.alphaValue = 1
            cat.panel.ignoresMouseEvents = false
            cat.place(on: screen, at: .random(in: screen.midX - 200...screen.midX + 200))
        }
        primary?.bubbles.showSpeech("mrrp!", duration: 1.2)
    }

    var isSleeping: Bool { primary?.engine.isSleeping ?? false }

    func toggleSleep() {
        for cat in cats where !cat.isGuest {
            cat.engine.setSleeping(!cat.engine.isSleeping)
        }
        if isSleeping == false { endCursorNap() }
        onStateChanged?()
    }

    func setStayPut(_ value: Bool) {
        for cat in cats { cat.engine.stayPut = value }
    }

    func cleanupOnQuit() {
        if gagCursorHidden {
            gagCursorHidden = false
            CGDisplayShowCursor(CGMainDisplayID())
        }
    }

    private func persist() {
        CatStore.save(cats.compactMap { $0.spec })
    }

    private var adoptionTimes: [CFTimeInterval] = []

    private func addCat(spec: CatSpec) {
        let now = CACurrentMediaTime()
        adoptionTimes.removeAll { now - $0 > 60 }
        guard adoptionTimes.count < 15 else {
            primary?.bubbles.showSpeech("slow down!! adoption papers take time (15/min)", duration: 2.6)
            return
        }
        adoptionTimes.append(now)
        let cat = makeCat(look: spec.look, isGuest: false, spec: spec)
        cat.place(on: primaryScreen().frame, at: .random(in: primaryScreen().frame.midX - 200...primaryScreen().frame.midX + 200))
        cat.bubbles.showSpeech("hello! i'm \(spec.name)", duration: 2.2)
        persist()
        onStateChanged?()
    }

    private func recolor(_ cat: Cat, to coat: Coat) {
        guard let old = cat.spec else { return }
        let spec = CatSpec(name: old.name, coatId: coat.id, customGrid: old.customGrid)
        cat.spec = spec
        cat.setLook(spec.look)
        persist()
    }

    private func removeCat(_ cat: Cat) {
        guard cats.filter({ !$0.isGuest }).count > 1 else { return }
        cat.teardown()
        cats.removeAll { $0 === cat }
        persist()
        onStateChanged?()
    }

    func buildCatContextMenu(for cat: Cat) -> NSMenu {
        let menu = NSMenu()
        let name = cat.spec?.name ?? cat.look.name
        let header = NSMenuItem(title: cat.isGuest ? "\(name) (visiting)" : name, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(ClosureItem(cat.engine.isSleeping ? "Wake Up" : "Sleep") { [weak self, weak cat] in
            guard let self, let cat else { return }
            if self.nappingCat === cat {
                self.endCursorNap()
            } else {
                cat.engine.setSleeping(!cat.engine.isSleeping)
            }
            self.onStateChanged?()
        })
        menu.addItem(ClosureItem("Stay Put", state: cat.engine.stayPut ? .on : .off) { [weak self, weak cat] in
            guard let cat else { return }
            cat.engine.stayPut.toggle()
            self?.onStateChanged?()
        })
        menu.addItem(NSMenuItem.separator())
        if let global = contextMenuProvider?() {
            for item in global.items {
                global.removeItem(item)
                menu.addItem(item)
            }
        }
        return menu
    }

    func buildCatsMenu() -> NSMenu {
        let menu = NSMenu()
        let add = NSMenuItem(title: "Add a Cat", action: nil, keyEquivalent: "")
        let addMenu = NSMenu()
        for coat in Coat.all {
            addMenu.addItem(ClosureItem(coat.name) { [weak self] in
                self?.addCat(spec: CatSpec(name: coat.name, coatId: coat.id))
            })
        }
        addMenu.addItem(NSMenuItem.separator())
        addMenu.addItem(ClosureItem("Draw Your Own…") { [weak self] in
            self?.pixelDrawer.show(baseCoat: Coat.all[0])
        })
        add.submenu = addMenu
        menu.addItem(add)
        menu.addItem(NSMenuItem.separator())

        let permanent = cats.filter { !$0.isGuest }
        let header = NSMenuItem(title: "Your Cats", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for cat in permanent {
            let item = NSMenuItem(title: "  \(cat.spec?.name ?? cat.look.name)", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            let recolorHeader = NSMenuItem(title: "Change Coat", action: nil, keyEquivalent: "")
            recolorHeader.isEnabled = false
            sub.addItem(recolorHeader)
            for coat in Coat.all {
                let on: NSControl.StateValue = (cat.spec?.coatId == coat.id) ? .on : .off
                sub.addItem(ClosureItem(coat.name, state: on) { [weak self, weak cat] in
                    guard let self, let cat else { return }
                    self.recolor(cat, to: coat)
                })
            }
            sub.addItem(NSMenuItem.separator())
            sub.addItem(ClosureItem("Remove This Cat", enabled: permanent.count > 1) { [weak self, weak cat] in
                guard let self, let cat else { return }
                self.removeCat(cat)
            })
            item.submenu = sub
            menu.addItem(item)
        }
        return menu
    }

    func sniffDesktopIcons() {
        guard let cat = primary, !cat.engine.isSleeping, cat.heldFile == nil else { return }
        finder.desktopIconXPositions { [weak self, weak cat] icons in
            guard let self, let cat, let target = icons.randomElement() else { return }
            let f = self.primaryScreen().frame
            let x = max(f.minX + 30, min(f.maxX - 30, target.x))
            cat.engine.goInvestigate(x: x) { [weak cat] in
                cat?.bubbles.showSpeech("*sniff sniff*", duration: 1.6)
            }
        }
    }

    func digUpOldFile() {
        guard let cat = primary, !cat.engine.isSleeping, cat.heldFile == nil,
              let url = watcher.randomOldFile() else { return }
        let f = primaryScreen().frame
        let x = CGFloat.random(in: f.midX - 350...f.midX + 350)
        cat.engine.goDig(at: x) { [weak cat] in
            guard let cat else { return }
            cat.heldFile = url
            cat.bubbles.showSpeech("remember this? \(url.lastPathComponent)", duration: 3.0)
        }
    }
}
