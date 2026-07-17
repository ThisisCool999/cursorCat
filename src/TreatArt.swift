import AppKit

enum TreatArt {
    static let grids: [TreatKind: [String]] = [
        .fish: [
            "................",
            "................",
            "....KKKKK.......",
            "..KKFFFFFK......",
            ".KFWFFFFFFK..K..",
            ".KFFFFFFFFFK.KK.",
            ".KFFFFFFFFFKKFK.",
            ".KFFFFFFFFFK.KK.",
            "..KKFFFFFK...K..",
            "....KKKKK.......",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
        .biscuit: [
            "................",
            "................",
            "................",
            ".....KKKKKK.....",
            "...KKOOOOOOKK...",
            "..KOOODOOOOOOK..",
            "..KOOOOOOODOOK..",
            "..KODOOOOOOOOK..",
            "..KOOOOOODOOOK..",
            "...KKOOOOOOKK...",
            ".....KKKKKK.....",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
        .water: [
            "................",
            ".......K........",
            "......KUK.......",
            "......KUK.......",
            ".....KUUUK......",
            "....KUUUUUK.....",
            "...KUWUUUUUK....",
            "...KUUUUUUUK....",
            "...KUUUUUUUK....",
            "....KUUUUUK.....",
            ".....KKKKK......",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
        .chocolate: [
            "................",
            "................",
            "................",
            "..KKKKKKKKKKKK..",
            "..KDDDKDDDKDDK..",
            "..KDDDKDDDKDDK..",
            "..KKKKKKKKKKKK..",
            "..KDDDKDDDKDDK..",
            "..KDDDKDDDKDDK..",
            "..KKKKKKKKKKKK..",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
        .lemon: [
            "................",
            "................",
            "................",
            "................",
            ".....KKKKKK.....",
            "...KKLLLLLLKK...",
            "..KLLWLLLLLLLK..",
            "..KLLLLLLLLLLK..",
            "...KKLLLLLLKK...",
            ".....KKKKKK.....",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
    ]

    static let miniSleep1: [String] = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "...K...K........",
        "..KPKKKPK.......",
        "..KBBBBBK.KKK...",
        ".KBBKKBBBKKBBK..",
        ".KBBBBBBBBBBBK..",
        ".KBBBBBBBBBBBK..",
        "..KBBBBBBBBBK...",
        "...KKKKKKKKK....",
        "................",
        "................",
        "................",
    ]

    private static var cache: [String: CGImage] = [:]

    static func cg(_ kind: TreatKind) -> CGImage {
        let key = "treat|\(kind.rawValue)"
        if let hit = cache[key] { return hit }
        let image = SpriteRenderer.cgImage(grid: grids[kind]!)
        cache[key] = image
        return image
    }

    static func miniSleep(_ frame: Int, look: CatLook) -> CGImage {
        let key = "mini|\(look.id)|\(frame % 2)"
        if let hit = cache[key] { return hit }
        var grid = miniSleep1
        if frame % 2 == 1 {
            grid = [String(repeating: ".", count: 16)] + grid.dropLast()
        }
        let image = SpriteRenderer.cgImage(grid: grid, colors: look.coat.colorMap)
        cache[key] = image
        return image
    }
}
