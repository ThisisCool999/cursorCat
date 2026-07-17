import AppKit

final class WindowTracker {
    var ownWindowNumbers: () -> Set<CGWindowID> = { [] }
    private(set) var platforms: [Platform] = []

    private var timer: Timer?

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refreshNow()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refreshNow() {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        guard let primaryScreen = NSScreen.screens.first else {
            platforms = []
            return
        }
        let primaryFrame = primaryScreen.frame
        let primaryHeight = primaryFrame.maxY
        let topLimit = primaryScreen.visibleFrame.maxY - 8
        let bottomLimit = primaryFrame.minY + 40
        let ownNumbers = ownWindowNumbers()
        let currentPID = Int(getpid())

        var occluders: [NSRect] = []
        var candidates: [(id: CGWindowID, rect: NSRect, z: Int)] = []

        for info in infoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int, ownerPID != currentPID else { continue }
            guard let number = info[kCGWindowNumber as String] as? Int else { continue }
            let windowID = CGWindowID(number)
            if ownNumbers.contains(windowID) { continue }
            let alpha = (info[kCGWindowAlpha as String] as? Double) ?? 1.0
            guard alpha > 0.1 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            let rect = NSRect(x: cgBounds.origin.x,
                              y: primaryHeight - cgBounds.origin.y - cgBounds.height,
                              width: cgBounds.width,
                              height: cgBounds.height)
            let z = occluders.count
            occluders.append(rect)
            guard cgBounds.width >= 100, cgBounds.height >= 60 else { continue }
            guard rect.intersects(primaryFrame) else { continue }
            guard rect.maxY <= topLimit else { continue }
            guard rect.maxY >= bottomLimit else { continue }
            candidates.append((windowID, rect, z))
        }

        var newPlatforms: [Platform] = []
        for candidate in candidates {
            let rect = candidate.rect
            let lower = max(rect.minX, primaryFrame.minX)
            let upper = min(rect.maxX, primaryFrame.maxX)
            guard upper - lower >= 96 else { continue }
            var segments: [ClosedRange<CGFloat>] = [lower...upper]
            for frontIndex in 0..<candidate.z {
                let front = occluders[frontIndex]
                guard front.minY < rect.maxY + 56, front.maxY > rect.maxY + 4 else { continue }
                segments = subtracting(front.minX...front.maxX, from: segments)
                if segments.isEmpty { break }
            }
            let walkable = segments.filter { $0.upperBound - $0.lowerBound >= 96 }
            if walkable.isEmpty { continue }
            newPlatforms.append(Platform(windowID: candidate.id, rect: rect, walkable: walkable))
        }
        platforms = newPlatforms
    }

    func platform(withID id: CGWindowID) -> Platform? {
        platforms.first { $0.windowID == id }
    }

    private func subtracting(_ interval: ClosedRange<CGFloat>, from segments: [ClosedRange<CGFloat>]) -> [ClosedRange<CGFloat>] {
        var result: [ClosedRange<CGFloat>] = []
        for segment in segments {
            if interval.upperBound <= segment.lowerBound || interval.lowerBound >= segment.upperBound {
                result.append(segment)
                continue
            }
            if interval.lowerBound > segment.lowerBound {
                result.append(segment.lowerBound...interval.lowerBound)
            }
            if interval.upperBound < segment.upperBound {
                result.append(interval.upperBound...segment.upperBound)
            }
        }
        return result
    }
}
