import AppKit

final class FinderBridge {
    private let scriptQueue = DispatchQueue(label: "mochi.FinderBridge.osascript")

    func selectedFiles(completion: @escaping ([URL]) -> Void) {
        runOSAScript(Self.selectionScript) { output in
            guard let output = output else {
                completion([])
                return
            }
            let urls = output
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { URL(fileURLWithPath: $0) }
            completion(urls)
        }
    }

    func desktopIconXPositions(completion: @escaping ([(url: URL, x: CGFloat)]) -> Void) {
        runOSAScript(Self.desktopIconsScript) { output in
            guard let output = output else {
                completion([])
                return
            }
            var icons: [(url: URL, x: CGFloat)] = []
            for line in output.split(separator: "\n") {
                let fields = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                guard fields.count == 2 else { continue }
                let path = String(fields[0])
                guard !path.isEmpty,
                      let x = Double(fields[1].trimmingCharacters(in: .whitespaces))
                else { continue }
                icons.append((url: URL(fileURLWithPath: path), x: CGFloat(x)))
            }
            completion(icons)
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private static let selectionScript = """
    tell application "Finder"
    set out to ""
    repeat with f in (get selection)
    try
    set out to out & POSIX path of (f as alias) & linefeed
    end try
    end repeat
    return out
    end tell
    """

    private static let desktopIconsScript = """
    tell application "Finder"
    set out to ""
    repeat with di in (get items of desktop)
    try
    set p to desktop position of di
    set out to out & POSIX path of (di as alias) & tab & ((item 1 of p) as text) & linefeed
    end try
    end repeat
    return out
    end tell
    """

    private func runOSAScript(_ source: String, resultHandler: @escaping (String?) -> Void) {
        scriptQueue.async {
            let finish: (String?) -> Void = { value in
                DispatchQueue.main.async {
                    resultHandler(value)
                }
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                finish(nil)
                return
            }
            var outputData = Data()
            let readCompleted = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .utility).async {
                outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                readCompleted.signal()
            }
            if readCompleted.wait(timeout: .now() + 8) == .timedOut {
                process.terminate()
                _ = readCompleted.wait(timeout: .now() + 2)
                finish(nil)
                return
            }
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                finish(nil)
                return
            }
            let text = String(data: outputData, encoding: .utf8) ?? ""
            finish(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
