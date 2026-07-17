import AppKit

final class DesktopWatcher {
    var onNewFiles: (([URL]) -> Void)?

    private let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    private var knownNames: Set<String> = []
    private var source: DispatchSourceFileSystemObject?
    private var pendingScan: DispatchWorkItem?

    func start() {
        stop()
        guard let desktopURL else { return }
        knownNames = listNames()
        let fd = open(desktopURL.path, O_EVTONLY)
        if fd < 0 { return }
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        newSource.setEventHandler { [weak self] in
            self?.scheduleScan()
        }
        newSource.setCancelHandler {
            close(fd)
        }
        source = newSource
        newSource.resume()
    }

    func stop() {
        pendingScan?.cancel()
        pendingScan = nil
        source?.cancel()
        source = nil
    }

    func randomOldFile() -> URL? {
        guard let desktopURL else { return nil }
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else { return nil }
        let cutoff = Date(timeIntervalSinceNow: -30 * 24 * 60 * 60)
        let candidates = items.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            if values.isDirectory == true && url.pathExtension == "app" { return false }
            guard let modified = values.contentModificationDate else { return false }
            return modified < cutoff
        }
        return candidates.randomElement()
    }

    private func listNames() -> Set<String> {
        guard let desktopURL else { return [] }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: desktopURL.path)) ?? []
        return Set(names.filter { !$0.hasPrefix(".") })
    }

    private func scheduleScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.scanForNewFiles()
        }
        pendingScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func scanForNewFiles() {
        guard let desktopURL else { return }
        let current = listNames()
        let added = current.subtracting(knownNames)
        knownNames = current
        if added.isEmpty { return }
        let urls = added.sorted().map { desktopURL.appendingPathComponent($0) }
        onNewFiles?(urls)
    }
}
