import AppKit

final class SpotlightFetcher {
    private final class TimeoutFlag {
        private let lock = NSLock()
        private var raised = false

        func raise() {
            lock.lock()
            raised = true
            lock.unlock()
        }

        var isRaised: Bool {
            lock.lock()
            defer { lock.unlock() }
            return raised
        }
    }

    private static let excludedPathFragments = ["/Library/", "/.Trash/", "/node_modules/", "/.git/", "/Applications/", ".app/"]
    private static let resultCap = 2000
    private static let timeoutSeconds: TimeInterval = 5
    private static let recencyWindow: TimeInterval = 365 * 24 * 60 * 60

    private let workQueue = DispatchQueue(label: "Mochi.SpotlightFetcher.work", qos: .userInitiated)
    private let timeoutQueue = DispatchQueue(label: "Mochi.SpotlightFetcher.timeout")
    private let stateLock = NSLock()
    private var generation = 0
    private var activeProcess: Process?

    func fetch(_ query: String, completion: @escaping (URL?) -> Void) {
        let fetchGeneration = advanceGeneration()
        let tokens = SpotlightFetcher.tokenize(query)
        guard !tokens.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let metadataQuery = SpotlightFetcher.metadataQuery(for: tokens)
        workQueue.async {
            self.runSearch(metadataQuery: metadataQuery, tokens: tokens, fetchGeneration: fetchGeneration, completion: completion)
        }
    }

    func cancel() {
        _ = advanceGeneration()
    }

    private func advanceGeneration() -> Int {
        stateLock.lock()
        generation += 1
        let newGeneration = generation
        let staleProcess = activeProcess
        activeProcess = nil
        stateLock.unlock()
        if let staleProcess, staleProcess.isRunning {
            staleProcess.terminate()
        }
        return newGeneration
    }

    private func clearActiveProcess(_ process: Process) {
        stateLock.lock()
        if activeProcess === process {
            activeProcess = nil
        }
        stateLock.unlock()
    }

    private func deliver(_ url: URL?, fetchGeneration: Int, completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            self.stateLock.lock()
            let stillCurrent = self.generation == fetchGeneration
            self.stateLock.unlock()
            if stillCurrent {
                completion(url)
            }
        }
    }

    private func runSearch(metadataQuery: String, tokens: [String], fetchGeneration: Int, completion: @escaping (URL?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-0", "-onlyin", NSHomeDirectory(), metadataQuery]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        stateLock.lock()
        guard generation == fetchGeneration else {
            stateLock.unlock()
            return
        }
        activeProcess = process
        stateLock.unlock()

        do {
            try process.run()
        } catch {
            clearActiveProcess(process)
            deliver(nil, fetchGeneration: fetchGeneration, completion: completion)
            return
        }

        stateLock.lock()
        let supersededDuringLaunch = generation != fetchGeneration
        stateLock.unlock()
        if supersededDuringLaunch {
            process.terminate()
        }

        let timeoutFlag = TimeoutFlag()
        timeoutQueue.asyncAfter(deadline: .now() + SpotlightFetcher.timeoutSeconds) { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let ownsProcess = self.generation == fetchGeneration && self.activeProcess === process
            self.stateLock.unlock()
            guard ownsProcess, process.isRunning else { return }
            timeoutFlag.raise()
            process.terminate()
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        clearActiveProcess(process)

        stateLock.lock()
        let stillCurrent = generation == fetchGeneration
        stateLock.unlock()
        guard stillCurrent else { return }

        if timeoutFlag.isRaised, process.terminationReason == .uncaughtSignal {
            deliver(nil, fetchGeneration: fetchGeneration, completion: completion)
            return
        }

        let bestURL = SpotlightFetcher.bestMatch(in: outputData, tokens: tokens)
        deliver(bestURL, fetchGeneration: fetchGeneration, completion: completion)
    }

    private static func tokenize(_ query: String) -> [String] {
        query.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\\", with: "") }
            .filter { !$0.isEmpty }
    }

    private static func metadataQuery(for tokens: [String]) -> String {
        let fileNameClause = tokens.map { "kMDItemFSName == \"*\($0)*\"cd" }.joined(separator: " && ")
        let displayNameClause = tokens.map { "kMDItemDisplayName == \"*\($0)*\"cd" }.joined(separator: " && ")
        return "(" + fileNameClause + ") || (" + displayNameClause + ")"
    }

    private static func bestMatch(in outputData: Data, tokens: [String]) -> URL? {
        let candidatePaths = outputData.split(separator: 0)
            .prefix(resultCap)
            .compactMap { String(data: $0, encoding: .utf8) }
            .filter { path in !excludedPathFragments.contains { path.contains($0) } }
        guard !candidatePaths.isEmpty else { return nil }

        let spacedPhrase = tokens.joined(separator: " ")
        let mergedPhrase = tokens.joined()
        let firstToken = tokens[0]
        let now = Date()

        var bestPath: String?
        var bestScore = -Double.greatestFiniteMagnitude
        for path in candidatePaths {
            let pathScore = score(path: path, spacedPhrase: spacedPhrase, mergedPhrase: mergedPhrase, firstToken: firstToken, now: now)
            if pathScore > bestScore {
                bestScore = pathScore
                bestPath = path
            }
        }
        guard let bestPath else { return nil }
        return URL(fileURLWithPath: bestPath)
    }

    private static func score(path: String, spacedPhrase: String, mergedPhrase: String, firstToken: String, now: Date) -> Double {
        let fileName = (path as NSString).lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension.lowercased()
        var total = -Double(baseName.count)
        if baseName == spacedPhrase || baseName == mergedPhrase {
            total += 1000
        }
        if baseName.hasPrefix(firstToken) {
            total += 100
        }
        let fileURL = URL(fileURLWithPath: path)
        if let modificationDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            let age = now.timeIntervalSince(modificationDate)
            if age <= recencyWindow {
                let clampedAge = max(age, 0)
                total += 200 * (1 - clampedAge / recencyWindow)
            }
        }
        return total
    }
}
