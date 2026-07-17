import AppKit

struct Platform: Equatable {
    let windowID: CGWindowID
    let rect: NSRect
    let walkable: [ClosedRange<CGFloat>]
}

enum TreatKind: String, CaseIterable {
    case fish
    case biscuit
    case water
    case chocolate
    case lemon

    var isBad: Bool {
        switch self {
        case .chocolate, .lemon:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .fish: return "fish"
        case .biscuit: return "biscuit"
        case .water: return "water"
        case .chocolate: return "chocolate"
        case .lemon: return "lemon"
        }
    }
}

struct MenuActions {
    var fetch: () -> Void = {}
    var grabFinderSelection: () -> Void = {}
    var toggleSleep: () -> Void = {}
    var toggleStayPut: () -> Void = {}
    var dropHeldFile: () -> Void = {}
    var revealHeldFile: () -> Void = {}
    var openHeldFile: () -> Void = {}
    var showTreatBox: () -> Void = {}
    var showHelp: () -> Void = {}
    var summon: () -> Void = {}
    var buildCatsMenu: () -> NSMenu = { NSMenu() }
    var quit: () -> Void = {}
}
