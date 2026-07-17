import AppKit

enum Surface: Equatable {
    case ground
    case windowTop(CGWindowID)
    case leftWall
    case rightWall
    case ceiling
    case air
}

enum Activity: Equatable {
    case idle
    case walk
    case run
    case chase
    case pounceCrouch
    case sniff
    case dig
    case sleep
    case fall
    case dragged
    case squash
    case offer
    case errandWalk
    case approachTreat
    case eat
    case recoil
    case flee
    case cursorNap
    case tongueEat
}

struct PetEnvironment {
    var groundY: CGFloat
    var ceilingY: CGFloat
    var leftWallX: CGFloat
    var rightWallX: CGFloat
    var platforms: [Platform]
    var cursor: CGPoint
    var cursorSpeed: CGFloat
    var notchRange: ClosedRange<CGFloat>?
    var treat: TreatKind?

    func platform(withID id: CGWindowID) -> Platform? {
        platforms.first { $0.windowID == id }
    }
}

struct RenderState {
    var panelOrigin: CGPoint
    var frameKey: String
    var flipH: Bool
    var flipV: Bool
    var rotation: SpriteRotation
    var heldIconCenter: CGPoint?
    var showShadow: Bool
    var hidden: Bool
    var tongueFrom: CGPoint? = nil
    var tongueTo: CGPoint? = nil
    var fakeCursor: CGPoint? = nil
}

enum Errand {
    case dig(() -> Void)
    case sniffSpot(() -> Void)
    case trashRun(() -> Void)
}

final class PetEngine {
    static let scale: CGFloat = 3
    static let inset: CGFloat = 8
    static let panelSize: CGFloat = 32 * scale + 2 * inset

    private(set) var position = CGPoint(x: 400, y: 600)
    private var velocity = CGVector.zero
    private(set) var surface = Surface.air
    private(set) var activity = Activity.fall
    private var facing: CGFloat = 1
    private var climbDir: CGFloat = 1
    private var activityTimeLeft: TimeInterval = 1
    private var animTime: TimeInterval = 0
    private var now: TimeInterval = 0
    private var surprisedUntil: TimeInterval = -1
    private var lastInteraction: TimeInterval = 0
    private var wasPounceLeap = false
    private var sleepRequested = false
    private var speedJitter: CGFloat = 1
    private var napPlanned = false
    private var napDeadline: TimeInterval = 0
    private var treatCooldownUntil: TimeInterval = 0
    private var recoilCooldownUntil: TimeInterval = 0
    private var recoilTreat: TreatKind?
    private var cursorLock = CGPoint.zero
    private var tongueStage = 0
    private(set) var rainbowRun = false
    var stayPut = false
    var isHoldingFile = false
    var onPounce: (() -> Void)?
    var onTreatReaction: ((TreatKind) -> Void)?
    var onEnterCursorNap: (() -> Void)?
    var onCursorEaten: (() -> Void)?
    var onCursorSpat: (() -> Void)?
    var tongueGate: (() -> Bool)?

    var facingDirection: CGFloat { facing }

    private var pendingErrand: (target: CGFloat, errand: Errand)?
    private var errandFinish: (() -> Void)?
    private var ridingRect: NSRect?
    private var dragSamples: [(t: TimeInterval, p: CGPoint)] = []
    private var grabOffset = CGVector.zero

    private let walkSpeed: CGFloat = 62
    private let runSpeed: CGFloat = 175
    private let climbSpeed: CGFloat = 55
    private let gravity: CGFloat = -2400
    private let maxFallSpeed: CGFloat = -1650

    var isSleeping: Bool { activity == .sleep || activity == .cursorNap || sleepRequested }
    var isNappingInCursor: Bool { activity == .cursorNap }

    func placeAtStart(screen: NSRect) {
        position = CGPoint(x: screen.midX, y: screen.maxY - 200)
        surface = .air
        activity = .fall
        velocity = .zero
    }

    func noteInteraction() {
        lastInteraction = now
    }

    func surprise() {
        surprisedUntil = now + 0.8
    }

    func setSleeping(_ sleeping: Bool) {
        noteInteraction()
        if sleeping {
            guard activity != .cursorNap else { return }
            switch surface {
            case .ground, .windowTop:
                setActivity(.sleep, for: 600)
                sleepRequested = false
            default:
                sleepRequested = true
                detachAndFall()
            }
        } else {
            sleepRequested = false
            if activity == .cursorNap {
                wakeFromCursorNap(at: position)
            } else if activity == .sleep {
                setActivity(.idle, for: .random(in: 1...3))
            }
        }
    }

    func wakeFromCursorNap(at point: CGPoint) {
        noteInteraction()
        position = point
        velocity = CGVector(dx: 0, dy: -40)
        surface = .air
        setActivity(.fall, for: 30)
    }

    func stopOffering() {
        if activity == .offer {
            setActivity(.idle, for: .random(in: 2...4))
        }
    }

    func goDig(at targetX: CGFloat?, completion: @escaping () -> Void) {
        startErrand(target: targetX ?? position.x, errand: .dig(completion))
    }

    func goInvestigate(x: CGFloat, completion: @escaping () -> Void) {
        startErrand(target: x, errand: .sniffSpot(completion))
    }

    func goTrash(at x: CGFloat, completion: @escaping () -> Void) {
        startErrand(target: x, errand: .trashRun(completion))
    }

    private func startErrand(target: CGFloat, errand: Errand) {
        noteInteraction()
        sleepRequested = false
        if activity == .cursorNap {
            wakeFromCursorNap(at: position)
        }
        errandFinish = nil
        pendingErrand = (target, errand)
        switch surface {
        case .ground:
            setActivity(.errandWalk, for: 60)
        case .air:
            break
        default:
            detachAndFall()
        }
    }

    func beginDrag(at point: CGPoint) {
        noteInteraction()
        grabOffset = CGVector(dx: position.x - point.x, dy: position.y - point.y)
        surface = .air
        activity = .dragged
        velocity = .zero
        ridingRect = nil
        wasPounceLeap = false
        pendingErrand = nil
        errandFinish = nil
        dragSamples = [(now, point)]
    }

    func dragMoved(to point: CGPoint) {
        position = CGPoint(x: point.x + grabOffset.dx, y: point.y + grabOffset.dy)
        dragSamples.append((now, point))
        while let first = dragSamples.first, now - first.t > 0.12 {
            dragSamples.removeFirst()
        }
    }

    func endDrag(at point: CGPoint) {
        dragMoved(to: point)
        var v = CGVector.zero
        if let first = dragSamples.first, let last = dragSamples.last, last.t - first.t > 0.016 {
            let span = CGFloat(last.t - first.t)
            v = CGVector(dx: (last.p.x - first.p.x) / span, dy: (last.p.y - first.p.y) / span)
        }
        v.dx = max(-1900, min(1900, v.dx))
        v.dy = max(-1900, min(1900, v.dy))
        velocity = v
        surface = .air
        setActivity(.fall, for: 30)
    }

    private func setActivity(_ a: Activity, for time: TimeInterval) {
        activity = a
        activityTimeLeft = time
        animTime = 0
        rainbowRun = (a == .run || a == .chase) && Double.random(in: 0...1) < 0.9
        switch a {
        case .walk, .run, .errandWalk, .chase, .approachTreat, .flee:
            speedJitter = .random(in: 0.75...1.3)
        case .sleep:
            napDeadline = now + .random(in: 12...35)
            napPlanned = Double.random(in: 0...1) < 0.55
        default:
            break
        }
    }

    private func detachAndFall() {
        let pushX: CGFloat
        switch surface {
        case .leftWall:
            pushX = 70
        case .rightWall:
            pushX = -70
        case .windowTop:
            pushX = facing * 40
            position.y -= 6
        default:
            pushX = facing * 40
        }
        surface = .air
        ridingRect = nil
        velocity = CGVector(dx: pushX, dy: 0)
        setActivity(.fall, for: 30)
    }

    private func enterCursorNap() {
        guard !isHoldingFile else { return }
        surface = .air
        velocity = .zero
        ridingRect = nil
        setActivity(.cursorNap, for: 9999)
        onEnterCursorNap?()
    }

    func tick(_ dt: TimeInterval, env: PetEnvironment) -> RenderState {
        now += dt
        animTime += dt
        activityTimeLeft -= dt

        switch activity {
        case .dragged:
            break
        case .cursorNap:
            position = env.cursor
        case .fall:
            stepFall(dt, env: env)
        case .squash:
            if activityTimeLeft <= 0 { afterLanding(env: env) }
        case .sleep:
            if napPlanned, now > napDeadline, !isHoldingFile {
                enterCursorNap()
            } else if activityTimeLeft <= 0 {
                setActivity(.idle, for: .random(in: 1.5...3.5))
            }
        case .idle, .offer:
            maybeApproachTreat(env: env)
            if activity == .idle || activity == .offer {
                maybeTongueEat(env: env)
            }
            if activity == .idle || activity == .offer {
                maybeChase(env: env)
                maybeAutoSleep()
            }
            if activityTimeLeft <= 0 { chooseNext(env: env) }
        case .walk, .run:
            maybeApproachTreat(env: env)
            if activity == .walk || activity == .run {
                maybeTongueEat(env: env)
            }
            if activity == .walk || activity == .run {
                maybeChase(env: env)
                stepLocomotion(dt, env: env)
                applyWander(dt)
            }
            if activityTimeLeft <= 0 { chooseNext(env: env) }
        case .tongueEat:
            if animTime >= 0.7, tongueStage == 0 {
                tongueStage = 1
                onCursorEaten?()
            }
            if activityTimeLeft <= 0 {
                onCursorSpat?()
                setActivity(.idle, for: .random(in: 1.5...3))
            }
        case .errandWalk:
            stepErrandWalk(dt, env: env)
        case .chase:
            stepChase(dt, env: env)
        case .approachTreat:
            stepApproachTreat(dt, env: env)
        case .eat:
            if activityTimeLeft <= 0 { setActivity(.idle, for: .random(in: 1.5...3)) }
        case .recoil:
            if activityTimeLeft <= 0 {
                if recoilTreat == .lemon {
                    setActivity(.flee, for: 2.2)
                } else {
                    setActivity(.idle, for: .random(in: 2...4))
                }
                recoilTreat = nil
            }
        case .flee:
            stepFlee(dt, env: env)
        case .pounceCrouch:
            if activityTimeLeft <= 0 {
                leapAtCursor(env: env)
            }
        case .sniff, .dig:
            if activityTimeLeft <= 0 {
                let finish = errandFinish
                errandFinish = nil
                setActivity(.idle, for: .random(in: 2...4))
                finish?()
                if isHoldingFile { setActivity(.offer, for: 9) }
            }
        }

        if case .windowTop = surface {
            validatePlatform(env: env)
        }

        return renderState(env: env)
    }

    private func stepFall(_ dt: TimeInterval, env: PetEnvironment) {
        velocity.dy = max(maxFallSpeed, velocity.dy + gravity * dt)
        let prev = position
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        if velocity.dy > 0, position.y >= env.ceilingY - 1 {
            position.y = env.ceilingY
            attach(to: .ceiling, env: env)
            return
        }
        if velocity.dx < 0, position.x <= env.leftWallX + 2 {
            position.x = env.leftWallX
            attach(to: .leftWall, env: env)
            return
        }
        if velocity.dx > 0, position.x >= env.rightWallX - 2 {
            position.x = env.rightWallX
            attach(to: .rightWall, env: env)
            return
        }
        if velocity.dy <= 0 {
            for platform in env.platforms {
                let top = platform.rect.maxY
                guard prev.y >= top, position.y <= top else { continue }
                guard platform.walkable.contains(where: { $0.lowerBound + 6 <= position.x && position.x <= $0.upperBound - 6 }) else { continue }
                position.y = top
                ridingRect = platform.rect
                land(on: .windowTop(platform.windowID), env: env)
                return
            }
            if position.y <= env.groundY {
                position.y = env.groundY
                land(on: .ground, env: env)
            }
        }
        position.x = max(env.leftWallX, min(env.rightWallX, position.x))
    }

    private func attach(to newSurface: Surface, env: PetEnvironment) {
        surface = newSurface
        velocity = .zero
        wasPounceLeap = false
        switch newSurface {
        case .leftWall, .rightWall:
            climbDir = 1
        case .ceiling:
            facing = Bool.random() ? 1 : -1
        default:
            break
        }
        setActivity(.walk, for: .random(in: 2...5))
        if sleepRequested || pendingErrand != nil {
            detachAndFall()
        }
    }

    private func land(on newSurface: Surface, env: PetEnvironment) {
        let impact = abs(velocity.dy)
        surface = newSurface
        velocity = .zero
        let pounced = wasPounceLeap
        wasPounceLeap = false
        if pounced {
            onPounce?()
            let cursorDistance = hypot(env.cursor.x - position.x, env.cursor.y - position.y)
            if cursorDistance < 90, !isHoldingFile, Double.random(in: 0...1) < 0.35 {
                enterCursorNap()
                return
            }
        }
        if impact > 1500 {
            setActivity(.squash, for: 0.14)
        } else {
            afterLanding(env: env)
        }
    }

    private func afterLanding(env: PetEnvironment) {
        if sleepRequested {
            sleepRequested = false
            setActivity(.sleep, for: 600)
            return
        }
        if pendingErrand != nil {
            if case .ground = surface {
                setActivity(.errandWalk, for: 60)
            } else {
                detachAndFall()
            }
            return
        }
        setActivity(.idle, for: .random(in: 1.2...3.5))
    }

    private func stepLocomotion(_ dt: TimeInterval, env: PetEnvironment) {
        let speed = (activity == .run ? runSpeed : walkSpeed) * speedJitter
        switch surface {
        case .ground:
            position.x += facing * speed * dt
            handleGroundEdges(env: env)
        case .windowTop:
            position.x += facing * speed * dt
            handlePlatformEdges(env: env)
        case .leftWall, .rightWall:
            position.y += climbDir * climbSpeed * speedJitter * dt
            handleWallEnds(env: env)
        case .ceiling:
            position.x += facing * climbSpeed * speedJitter * dt
            handleCeilingEdges(env: env)
        case .air:
            break
        }
    }

    private func applyWander(_ dt: TimeInterval) {
        let flipRate: Double = activity == .run ? 0.45 : 0.16
        if Double.random(in: 0...1) < flipRate * dt {
            facing = -facing
        }
        if Double.random(in: 0...1) < 0.22 * dt {
            setActivity(.idle, for: .random(in: 0.3...1.3))
        }
    }

    private func handleGroundEdges(env: PetEnvironment) {
        if position.x <= env.leftWallX + 14, facing < 0 {
            position.x = env.leftWallX + 14
            if !stayPut, pendingErrand == nil, activity != .flee, Double.random(in: 0...1) < 0.55 {
                position.x = env.leftWallX
                surface = .leftWall
                climbDir = 1
                setActivity(.walk, for: .random(in: 3...7))
            } else {
                facing = 1
            }
        }
        if position.x >= env.rightWallX - 14, facing > 0 {
            position.x = env.rightWallX - 14
            if !stayPut, pendingErrand == nil, activity != .flee, Double.random(in: 0...1) < 0.55 {
                position.x = env.rightWallX
                surface = .rightWall
                climbDir = 1
                setActivity(.walk, for: .random(in: 3...7))
            } else {
                facing = -1
            }
        }
    }

    private func handlePlatformEdges(env: PetEnvironment) {
        guard case let .windowTop(id) = surface, let platform = env.platform(withID: id) else {
            detachAndFall()
            return
        }
        guard let segment = platform.walkable.first(where: { $0.lowerBound - 20 <= position.x && position.x <= $0.upperBound + 20 }) else {
            detachAndFall()
            return
        }
        if position.x <= segment.lowerBound + 10, facing < 0 {
            if Double.random(in: 0...1) < 0.3 {
                detachAndFall()
            } else {
                facing = 1
                position.x = segment.lowerBound + 10
            }
        }
        if position.x >= segment.upperBound - 10, facing > 0 {
            if Double.random(in: 0...1) < 0.3 {
                detachAndFall()
            } else {
                facing = -1
                position.x = segment.upperBound - 10
            }
        }
    }

    private func handleWallEnds(env: PetEnvironment) {
        if climbDir > 0, position.y >= env.ceilingY - 2 {
            position.y = env.ceilingY
            facing = surface == .leftWall ? 1 : -1
            surface = .ceiling
            setActivity(.walk, for: .random(in: 2...6))
        }
        if climbDir < 0, position.y <= env.groundY + 2 {
            position.y = env.groundY
            surface = .ground
            setActivity(.idle, for: .random(in: 1...3))
        }
    }

    private func handleCeilingEdges(env: PetEnvironment) {
        if let notch = env.notchRange, notch.contains(position.x + facing * 20) {
            detachAndFall()
            return
        }
        if facing < 0, position.x <= env.leftWallX + 4 {
            position.x = env.leftWallX
            surface = .leftWall
            climbDir = -1
            setActivity(.walk, for: .random(in: 2...5))
        }
        if facing > 0, position.x >= env.rightWallX - 4 {
            position.x = env.rightWallX
            surface = .rightWall
            climbDir = -1
            setActivity(.walk, for: .random(in: 2...5))
        }
    }

    private func stepErrandWalk(_ dt: TimeInterval, env: PetEnvironment) {
        guard let errand = pendingErrand else {
            setActivity(.idle, for: 2)
            return
        }
        guard case .ground = surface else {
            detachAndFall()
            return
        }
        let target = max(env.leftWallX + 20, min(env.rightWallX - 20, errand.target))
        let dx = target - position.x
        if abs(dx) < 6 {
            performErrand(errand.errand)
            pendingErrand = nil
            return
        }
        facing = dx > 0 ? 1 : -1
        let speed = (abs(dx) > 320 ? runSpeed : walkSpeed) * speedJitter
        position.x += facing * min(speed * dt, CGFloat(abs(dx)))
    }

    private func performErrand(_ errand: Errand) {
        switch errand {
        case .dig(let completion):
            errandFinish = completion
            setActivity(.dig, for: 1.5)
        case .sniffSpot(let completion):
            errandFinish = completion
            setActivity(.sniff, for: 2.2)
        case .trashRun(let completion):
            errandFinish = completion
            setActivity(.dig, for: 1.0)
        }
    }

    private func stepChase(_ dt: TimeInterval, env: PetEnvironment) {
        guard case .ground = surface else {
            setActivity(.idle, for: 1)
            return
        }
        let dx = env.cursor.x - position.x
        if abs(dx) < 52 {
            setActivity(.pounceCrouch, for: .random(in: 0.35...0.7))
            return
        }
        facing = dx > 0 ? 1 : -1
        position.x += facing * runSpeed * 1.15 * speedJitter * dt
        handleGroundEdges(env: env)
        if activityTimeLeft <= 0 {
            setActivity(.idle, for: .random(in: 1...3))
        }
    }

    private func leapAtCursor(env: PetEnvironment) {
        wasPounceLeap = true
        let rise = max(env.cursor.y - position.y + 30, 60)
        let vy = min(sqrt(2 * abs(gravity) * rise), 950)
        let apexTime = vy / abs(gravity)
        let dx = env.cursor.x - position.x
        let vx = max(-520, min(520, dx / max(apexTime, 0.18)))
        velocity = CGVector(dx: vx, dy: vy)
        facing = dx >= 0 ? 1 : -1
        surface = .air
        setActivity(.fall, for: 30)
    }

    private func stepApproachTreat(_ dt: TimeInterval, env: PetEnvironment) {
        guard let treat = env.treat, case .ground = surface else {
            setActivity(.idle, for: 1)
            return
        }
        let dx = env.cursor.x - position.x
        if abs(dx) < 46 {
            if env.cursor.y - position.y < 130 {
                onTreatReaction?(treat)
                if treat.isBad {
                    recoilCooldownUntil = now + .random(in: 8...15)
                    recoilTreat = treat
                    surprise()
                    setActivity(.recoil, for: 1.1)
                } else {
                    treatCooldownUntil = now + .random(in: 25...55)
                    setActivity(.eat, for: 2.4)
                }
            } else {
                setActivity(.idle, for: 1.4)
            }
            return
        }
        facing = dx > 0 ? 1 : -1
        let speed = (abs(dx) > 260 ? runSpeed : walkSpeed) * speedJitter
        position.x += facing * min(speed * dt, CGFloat(abs(dx)))
        handleGroundEdges(env: env)
        if activityTimeLeft <= 0 {
            setActivity(.idle, for: .random(in: 1...2))
        }
    }

    private func stepFlee(_ dt: TimeInterval, env: PetEnvironment) {
        guard case .ground = surface else {
            if activityTimeLeft <= 0 { setActivity(.walk, for: 2) }
            return
        }
        facing = env.cursor.x > position.x ? -1 : 1
        position.x += facing * runSpeed * 1.3 * speedJitter * dt
        handleGroundEdges(env: env)
        if activityTimeLeft <= 0 {
            setActivity(.idle, for: .random(in: 1.5...3))
        }
    }

    private func maybeApproachTreat(env: PetEnvironment) {
        guard let treat = env.treat, !stayPut, !isSleeping,
              pendingErrand == nil else { return }
        if treat.isBad {
            guard now > recoilCooldownUntil else { return }
        } else {
            guard now > treatCooldownUntil else { return }
        }
        switch surface {
        case .ground:
            guard abs(env.cursor.x - position.x) < 800 else { return }
            setActivity(.approachTreat, for: 12)
        case .windowTop, .leftWall, .rightWall, .ceiling:
            guard abs(env.cursor.x - position.x) < 500, env.cursor.y < position.y else { return }
            guard Double.random(in: 0...1) < 1.2 * (1.0 / 60.0) else { return }
            detachAndFall()
        case .air:
            break
        }
    }

    func feedNow(_ kind: TreatKind) -> Bool {
        guard !isSleeping, activity != .dragged, activity != .cursorNap else { return false }
        switch surface {
        case .ground, .windowTop:
            break
        default:
            return false
        }
        if kind.isBad {
            noteInteraction()
            recoilTreat = kind
            surprise()
            onTreatReaction?(kind)
            setActivity(.recoil, for: 1.1)
            return true
        }
        guard now > treatCooldownUntil else { return false }
        noteInteraction()
        treatCooldownUntil = now + .random(in: 20...45)
        onTreatReaction?(kind)
        setActivity(.eat, for: 2.4)
        return true
    }

    private func maybeTongueEat(env: PetEnvironment) {
        guard env.treat == nil, !isHoldingFile, !stayPut, !isSleeping, pendingErrand == nil else { return }
        switch surface {
        case .ground, .windowTop:
            break
        default:
            return
        }
        let distance = hypot(env.cursor.x - position.x, env.cursor.y - position.y)
        guard distance > 60, distance < 380 else { return }
        guard Double.random(in: 0...1) < 0.022 * (1.0 / 60.0) else { return }
        guard tongueGate?() ?? true else { return }
        cursorLock = env.cursor
        facing = env.cursor.x >= position.x ? 1 : -1
        tongueStage = 0
        setActivity(.tongueEat, for: 4.5)
    }

    func debugTongueEat(cursor: CGPoint) {
        cursorLock = cursor
        facing = cursor.x >= position.x ? 1 : -1
        tongueStage = 0
        setActivity(.tongueEat, for: 4.5)
    }

    private func mouthPoint() -> CGPoint {
        CGPoint(x: position.x + facing * 8, y: position.y + 46)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let k = max(0, min(1, t))
        return CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
    }

    private func maybeChase(env: PetEnvironment) {
        guard env.treat == nil, !stayPut, !isSleeping, pendingErrand == nil, case .ground = surface else { return }
        let dx = abs(env.cursor.x - position.x)
        let distance = hypot(env.cursor.x - position.x, env.cursor.y - position.y)
        let reachable = env.cursor.y < position.y + 340
        var rate = 0.0
        if env.cursorSpeed > 850, dx < 620, reachable { rate = 0.5 }
        else if distance < 110, env.cursorSpeed > 250 { rate = 1.5 }
        else if dx < 600, reachable { rate = 0.012 }
        guard rate > 0, Double.random(in: 0...1) < rate * (1.0 / 60.0) else { return }
        setActivity(.chase, for: 5)
    }

    private func maybeAutoSleep() {
        guard !stayPut, activity == .idle, now - lastInteraction > 150 else { return }
        switch surface {
        case .ground, .windowTop:
            if Double.random(in: 0...1) < 0.001 {
                setActivity(.sleep, for: .random(in: 60...200))
            }
        default:
            break
        }
    }

    private func jumpCandidate(env: PetEnvironment) -> (x: CGFloat, top: CGFloat)? {
        let options: [(x: CGFloat, top: CGFloat)] = env.platforms.compactMap { platform in
            let top = platform.rect.maxY
            let rise = top - position.y
            guard rise > 60, rise < 240 else { return nil }
            guard let segment = platform.walkable.first(where: {
                $0.lowerBound - 260 < position.x && position.x < $0.upperBound + 260 && $0.upperBound - $0.lowerBound > 60
            }) else { return nil }
            let targetX = max(segment.lowerBound + 25, min(segment.upperBound - 25, position.x + facing * 90))
            guard abs(targetX - position.x) < 280 else { return nil }
            return (targetX, top)
        }
        return options.randomElement()
    }

    private func jump(to candidate: (x: CGFloat, top: CGFloat)) {
        let rise = candidate.top - position.y
        let vy = min(sqrt(2 * abs(gravity) * (rise + 55)), 1150)
        let apexTime = vy / abs(gravity)
        let vx = max(-430, min(430, (candidate.x - position.x) / max(apexTime, 0.2)))
        velocity = CGVector(dx: vx, dy: vy)
        facing = vx >= 0 ? 1 : -1
        surface = .air
        ridingRect = nil
        setActivity(.fall, for: 30)
    }

    private func hop() {
        velocity = CGVector(dx: facing * 90, dy: 330)
        surface = .air
        ridingRect = nil
        setActivity(.fall, for: 30)
    }

    private func chooseNext(env: PetEnvironment) {
        if stayPut {
            setActivity(.idle, for: .random(in: 2...5))
            return
        }
        let jumpTarget = jumpCandidate(env: env)
        switch surface {
        case .ground:
            var options: [(Double, () -> Void)] = [
                (3.0, { self.facing = Bool.random() ? 1 : -1; self.setActivity(.walk, for: .random(in: 2.5...6)) }),
                (2.6, { self.facing = Bool.random() ? 1 : -1; self.setActivity(.run, for: .random(in: 2...4)) }),
                (1.2, { self.setActivity(.sniff, for: 1.8) }),
                (2.0, { self.setActivity(.idle, for: .random(in: 1.5...4)) }),
                (0.8, { self.hop() }),
            ]
            if let target = jumpTarget {
                options.append((1.8, { self.jump(to: target) }))
            }
            pick(options)
        case .windowTop:
            var options: [(Double, () -> Void)] = [
                (3.5, { self.facing = Bool.random() ? 1 : -1; self.setActivity(.walk, for: .random(in: 2...5)) }),
                (2.2, { self.setActivity(.idle, for: .random(in: 1.5...4.5)) }),
                (1.5, { self.detachAndFall() }),
                (0.8, { self.setActivity(.sniff, for: 1.6) }),
                (0.5, { self.hop() }),
            ]
            if let target = jumpTarget {
                options.append((1.2, { self.jump(to: target) }))
            }
            pick(options)
        case .leftWall, .rightWall:
            pick([
                (4, { self.setActivity(.walk, for: .random(in: 2...5)) }),
                (1, { self.climbDir = -self.climbDir; self.setActivity(.walk, for: .random(in: 2...4)) }),
                (1.4, { self.detachAndFall() }),
                (1.6, { self.setActivity(.idle, for: .random(in: 1...3)) }),
            ])
        case .ceiling:
            pick([
                (4, { self.setActivity(.walk, for: .random(in: 2...5)) }),
                (2, { self.detachAndFall() }),
                (1.4, { self.facing = -self.facing; self.setActivity(.walk, for: .random(in: 2...4)) }),
            ])
        case .air:
            setActivity(.fall, for: 30)
        }
    }

    private func pick(_ options: [(Double, () -> Void)]) {
        let total = options.reduce(0) { $0 + $1.0 }
        var roll = Double.random(in: 0..<total)
        for (weight, action) in options {
            roll -= weight
            if roll <= 0 {
                action()
                return
            }
        }
        options.last?.1()
    }

    private func validatePlatform(env: PetEnvironment) {
        guard case let .windowTop(id) = surface else { return }
        guard activity != .dragged else { return }
        guard let platform = env.platform(withID: id) else {
            detachAndFall()
            return
        }
        if let old = ridingRect {
            let dy = platform.rect.maxY - old.maxY
            if abs(dy) > 4 {
                detachAndFall()
                return
            }
            if abs(platform.rect.width - old.width) < 1 {
                position.x += platform.rect.minX - old.minX
            }
            position.y = platform.rect.maxY
        } else {
            position.y = platform.rect.maxY
        }
        ridingRect = platform.rect
        guard platform.walkable.contains(where: { $0.lowerBound - 24 <= position.x && position.x <= $0.upperBound + 24 }) else {
            detachAndFall()
            return
        }
    }

    private func renderState(env: PetEnvironment) -> RenderState {
        let key = currentFrameKey()
        var flipH = facing < 0
        var flipV = false
        var rotation = SpriteRotation.none

        switch surface {
        case .ceiling:
            flipV = true
        case .rightWall:
            rotation = .counterclockwise
            flipH = false
            flipV = climbDir < 0
        case .leftWall:
            rotation = .counterclockwise
            flipH = true
            flipV = climbDir < 0
        default:
            break
        }

        let half = PetEngine.panelSize / 2
        let size = PetEngine.panelSize
        let inset = PetEngine.inset
        var origin: CGPoint
        switch surface {
        case .ceiling:
            origin = CGPoint(x: position.x - half, y: position.y - size + inset)
        case .leftWall:
            origin = CGPoint(x: position.x - inset, y: position.y - half)
        case .rightWall:
            origin = CGPoint(x: position.x - size + inset, y: position.y - half)
        default:
            origin = CGPoint(x: position.x - half, y: position.y - inset)
        }

        var iconCenter: CGPoint?
        if isHoldingFile, rotation == .none, !flipV,
           activity != .sleep, activity != .squash, activity != .dig, activity != .cursorNap {
            let anchor = Sprites.mouthAnchors[key] ?? CGPoint(x: 16, y: 14)
            let ax = flipH ? 31 - anchor.x : anchor.x
            var center = CGPoint(
                x: inset + (ax + 0.5) * PetEngine.scale,
                y: inset + (31.5 - anchor.y) * PetEngine.scale
            )
            if key.hasPrefix("walk") {
                center.x += facing * 14
                center.y -= 4
            } else if key != "hold" {
                center.x += facing * 12
            }
            iconCenter = center
        }

        var grounded = false
        switch surface {
        case .ground, .windowTop:
            grounded = true
        default:
            grounded = false
        }

        var state = RenderState(
            panelOrigin: origin,
            frameKey: key,
            flipH: flipH,
            flipV: flipV,
            rotation: rotation,
            heldIconCenter: iconCenter,
            showShadow: grounded,
            hidden: activity == .cursorNap
        )

        if activity == .tongueEat {
            let mouth = mouthPoint()
            let t = animTime
            if t < 0.25 {
                state.tongueFrom = mouth
                state.tongueTo = lerp(mouth, cursorLock, 0.12 * (t / 0.25))
            } else if t < 0.7 {
                state.tongueFrom = mouth
                state.tongueTo = lerp(mouth, cursorLock, (t - 0.25) / 0.45)
            } else if t < 1.1 {
                let tip = lerp(mouth, cursorLock, 1 - (t - 0.7) / 0.4)
                state.tongueFrom = mouth
                state.tongueTo = tip
                state.fakeCursor = tip
            } else if t < 1.6 {
                state.fakeCursor = CGPoint(x: mouth.x + facing * 10, y: mouth.y - 2)
            } else if t >= 4.2 {
                state.fakeCursor = lerp(mouth, env.cursor, (t - 4.2) / 0.3)
            }
        }

        return state
    }

    private func currentFrameKey() -> String {
        if now < surprisedUntil, [.idle, .offer, .walk, .recoil].contains(activity) {
            return "surprised"
        }
        switch activity {
        case .idle:
            if isHoldingFile {
                switch surface {
                case .ground, .windowTop:
                    return "hold"
                default:
                    break
                }
            }
            if fmod(animTime, 4.7) < 0.16 { return "blink" }
            if fmod(animTime, 2.3) < 0.4 { return "sit2" }
            return "sit1"
        case .offer:
            return "hold"
        case .walk, .errandWalk, .chase, .run, .approachTreat, .flee:
            let onWallOrCeiling: Bool
            switch surface {
            case .leftWall, .rightWall, .ceiling:
                onWallOrCeiling = true
            default:
                onWallOrCeiling = false
            }
            let fast = activity == .run || activity == .chase || activity == .flee
            let fps: Double = fast ? 11 : (onWallOrCeiling ? 5 : 6)
            let cycle = ["walk1", "walk2", "walk3", "walk2"]
            return cycle[Int(animTime * fps) % 4]
        case .pounceCrouch:
            return "sniff1"
        case .sniff:
            return Int(animTime * 3) % 2 == 0 ? "sniff1" : "sniff2"
        case .dig, .eat:
            return Int(animTime * (activity == .eat ? 5 : 7)) % 2 == 0 ? "dig1" : "dig2"
        case .sleep, .cursorNap:
            return Int(animTime * 1.2) % 2 == 0 ? "sleep1" : "sleep2"
        case .fall:
            return "fall"
        case .dragged:
            return "carried"
        case .squash:
            return "squash"
        case .recoil:
            return "surprised"
        case .tongueEat:
            return animTime >= 1.1 && animTime < 4.2 ? "chew" : "tongueOut"
        }
    }
}
