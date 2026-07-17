import AppKit

struct Coat: Equatable {
    let id: String
    let name: String
    let body: NSColor
    let shade: NSColor
    let highlight: NSColor
    let marking: NSColor
    let belly: NSColor
    let earInner: NSColor
    let nose: NSColor

    var colorMap: [Character: NSColor] {
        var map = Palette.colors
        map["B"] = body
        map["S"] = shade
        map["H"] = highlight
        map["T"] = marking
        map["C"] = belly
        map["P"] = earInner
        map["N"] = nose
        return map
    }

    static let all: [Coat] = [
        Coat(id: "grey", name: "Grey Tabby",
             body: NSColor(hex: 0xC9C1B4), shade: NSColor(hex: 0xA79D8F),
             highlight: NSColor(hex: 0xDAD3C6), marking: NSColor(hex: 0x8C8274),
             belly: NSColor(hex: 0xF3EBDC), earInner: NSColor(hex: 0xEFADB5),
             nose: NSColor(hex: 0xD97F8E)),
        Coat(id: "orange", name: "Orange Tabby",
             body: NSColor(hex: 0xE8A85C), shade: NSColor(hex: 0xC6863C),
             highlight: NSColor(hex: 0xF2C583), marking: NSColor(hex: 0xB5652A),
             belly: NSColor(hex: 0xF7E7C6), earInner: NSColor(hex: 0xEFA0A8),
             nose: NSColor(hex: 0xD97F8E)),
        Coat(id: "black", name: "Void",
             body: NSColor(hex: 0x4A4550), shade: NSColor(hex: 0x35313B),
             highlight: NSColor(hex: 0x605A68), marking: NSColor(hex: 0x2E2837),
             belly: NSColor(hex: 0x6B6572), earInner: NSColor(hex: 0xC77E8A),
             nose: NSColor(hex: 0x9A6470)),
        Coat(id: "white", name: "Snow",
             body: NSColor(hex: 0xF3EFE8), shade: NSColor(hex: 0xD8D2C6),
             highlight: NSColor(hex: 0xFFFFFF), marking: NSColor(hex: 0xE2DACB),
             belly: NSColor(hex: 0xFFFFFF), earInner: NSColor(hex: 0xF3B8C0),
             nose: NSColor(hex: 0xE29AA6)),
        Coat(id: "tuxedo", name: "Tuxedo",
             body: NSColor(hex: 0x3A3640), shade: NSColor(hex: 0x2A2730),
             highlight: NSColor(hex: 0x4E4A56), marking: NSColor(hex: 0x2E2837),
             belly: NSColor(hex: 0xF6F2EA), earInner: NSColor(hex: 0xE6A6B0),
             nose: NSColor(hex: 0xC77E8A)),
        Coat(id: "siamese", name: "Siamese",
             body: NSColor(hex: 0xE6DAC5), shade: NSColor(hex: 0xC9BBA2),
             highlight: NSColor(hex: 0xF2E9D8), marking: NSColor(hex: 0x5A4636),
             belly: NSColor(hex: 0xF2E9D8), earInner: NSColor(hex: 0x8A6A54),
             nose: NSColor(hex: 0x8A6A54)),
        Coat(id: "calico", name: "Calico",
             body: NSColor(hex: 0xF0E7D6), shade: NSColor(hex: 0xD6C4A6),
             highlight: NSColor(hex: 0xFFFBF0), marking: NSColor(hex: 0xD98A3D),
             belly: NSColor(hex: 0xFFFBF0), earInner: NSColor(hex: 0xEFA0A8),
             nose: NSColor(hex: 0xD97F8E)),
        Coat(id: "blue", name: "Blue Russian",
             body: NSColor(hex: 0x8C97A6), shade: NSColor(hex: 0x6C7787),
             highlight: NSColor(hex: 0xA6B0BD), marking: NSColor(hex: 0x555F6E),
             belly: NSColor(hex: 0xC3CAD3), earInner: NSColor(hex: 0xD9A6B0),
             nose: NSColor(hex: 0xB98790)),
    ]

    static func by(id: String) -> Coat {
        all.first { $0.id == id } ?? all[0]
    }
}
