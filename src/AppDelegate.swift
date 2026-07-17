import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PetController!
    private var statusBar: StatusBarController!
    private var stayPut = false
    private var ambientTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = PetController()

        var actions = MenuActions()
        actions.fetch = { [weak self] in
            self?.controller.promptFetch()
        }
        actions.grabFinderSelection = { [weak self] in
            self?.controller.grabFinderSelection()
        }
        actions.toggleSleep = { [weak self] in
            guard let self else { return }
            self.controller.toggleSleep()
            self.refreshStatus()
        }
        actions.toggleStayPut = { [weak self] in
            guard let self else { return }
            self.stayPut.toggle()
            self.controller.setStayPut(self.stayPut)
            self.refreshStatus()
        }
        actions.dropHeldFile = { [weak self] in
            self?.controller.putDownHeldFile()
        }
        actions.revealHeldFile = { [weak self] in
            self?.controller.revealHeldFile()
        }
        actions.openHeldFile = { [weak self] in
            self?.controller.openHeldFile()
        }
        actions.showTreatBox = { [weak self] in
            self?.controller.toggleTreatBox()
        }
        actions.showHelp = { [weak self] in
            self?.controller.showHelp()
        }
        actions.summon = { [weak self] in
            self?.controller.summon()
        }
        actions.buildCatsMenu = { [weak self] in
            self?.controller.buildCatsMenu() ?? NSMenu()
        }
        actions.quit = {
            NSApp.terminate(nil)
        }

        statusBar = StatusBarController(actions: actions)
        controller.contextMenuProvider = { [weak self] in
            self?.statusBar.buildContextMenu() ?? NSMenu()
        }
        controller.onStateChanged = { [weak self] in
            self?.refreshStatus()
        }
        controller.start()
        refreshStatus()

        let timer = Timer(timeInterval: 210, repeats: true) { [weak self] _ in
            guard let self else { return }
            let roll = Double.random(in: 0...1)
            if roll < 0.3 {
                self.controller.sniffDesktopIcons()
            } else if roll < 0.42 {
                self.controller.digUpOldFile()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ambientTimer = timer
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.summon()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.cleanupOnQuit()
    }

    private func refreshStatus() {
        statusBar.update(
            isSleeping: controller.isSleeping,
            isStayPut: stayPut,
            heldFileName: controller.heldFile?.lastPathComponent
        )
    }
}
