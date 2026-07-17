import AppKit

enum SpriteRotation {
    case none
    case clockwise
    case counterclockwise
}

enum Sprites {
    static let size = 32

    private static let sit1: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "..........K...........K........",
        ".........KPK.........KPK.......",
        "........KPPPK.......KPPPK.......",
        "........KBBBKKKKKKKKKBBBK.......",
        ".......KBHHHHHHHBBBBBBBBBK......",
        ".......KBHHHBBBBBBBBBBBBBK......",
        ".......KBBBBBBBBBBBBBBBBBK......",
        ".......KBBBKKBBBBBBBKKBBBK......",
        ".......KBBBKKBBBBBBBKKBBBK......",
        ".......KBBBBBCCNNCCCBBBBBK......",
        ".......KBBBBBCKCCCKCBBBBBK......",
        ".......KBBBBBCCCCCCCBBBBBK......",
        ".......KSSSBBBBBBBBBBBSSSK......",
        "........KBBBBBBBBBBBBBBBK.......",
        "..........KBBBBBBBBBBBK........",
        ".........KBBBBBBBBBBBBBK.......",
        "........KBBBBBBBBBBBBBBK.......",
        ".......KBBBBBBBBBBBBBBBK.......",
        ".......KBBBBBBBBBBBBBBBK.......",
        ".......KBBBBBBBBBBBBBSSK.......",
        ".......KBBBBBBBBBBBBBSSK.......",
        ".......KBBBBBBBBBBKBBBBK.......",
        ".......KBBBBBBBBBBKBBBBK.......",
        "..KKKK.KBBBBBBBBBBKBBBBK.......",
        ".KBTBTBKBBBBBBBBBKCCCCCK.......",
        ".KBTBTBKBBBBBBBBBKCCCCCK.......",
        ".KKKKKKKKKKKKKKKKKKKKKKK.......",
    ]

    private static let walk1: [String] = [
        "................................",
        "................................",
        "................................",
        "..............K...........K.....",
        ".............KPK.........KPK....",
        "............KPPPK.......KPPPK...",
        "............KBBBKKKKKKKKKBBBK...",
        "...........KBHHHHHHHBBBBBBBBBK..",
        "...........KBHHHBBBBBBBBBBBBBK..",
        "...........KBBBBBBBBBBBBBBBBBK..",
        "...........KBBBKKBBBBBBBKKBBBK..",
        "...........KBBBKKBBBBBBBKKBBBK..",
        ".KK........KBBBBBCCNNCCCBBBBBK..",
        ".KBK.......KBBBBBCKCCCKCBBBBBK..",
        ".KTK.......KBBBBBCCCCCCCBBBBBK..",
        "..KBK......KSSSBBBBBBBBBBBSSSK..",
        "..KBK.......KBBBBBBBBBBBBBBBK...",
        "...KKKKKKKKKKKKKKKKKKK..........",
        "..KBBBTTBBTTBBBBBBBBBBK.........",
        "..KBBBBBBBBBBBBBBBBBBBK.........",
        "..KBBBBBBBBBBBBBBBBBBBK.........",
        "..KBBBBBBBBBBBBBBBBSSSK.........",
        "..KBBBCCCCCCCCCCCCCBBBK.........",
        "..KBBBCCCCCCCCCCCCCBBBK.........",
        "..KKKKKKKKKKKKKKKKKKKKK.........",
        "....SS.KBK......SS..KBK.........",
        "....SS.KBK......SS..KBK.........",
        "....SS.KBK......SS..KBK.........",
        "....SS.KBK......SS..KBK.........",
        "....SS.KBK......SS..KBK.........",
        ".......KCK..........KCK.........",
        ".......KKK..........KKK.........",
    ]

    private static let sleep1: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "......................K...K.....",
        ".....................KPK.KPK....",
        "......KKKKKKKKKKKKKKKKKKKKKK....",
        ".....KBHHHHHHHHBBBBBBBBBBBBK....",
        ".....KBBTTBBTTBBBBBBBBBBBBBK....",
        ".....KBBBBBBBBBBBBBBBKKBBKKK....",
        ".....KBBBBBBBBBBBBBBBBBCNNCK....",
        ".....KBBBBBBBBBBBBBBBBBBBBBK....",
        ".....KBBBBBBBBBBBBBBBBBBBBBK....",
        ".....KBCCCCCCBBBBBBBBBBBBBBK....",
        ".....KSSSBBBBBBBBBBBBBBBSSSK....",
        "......KKKKKKKKKKKKKKKKKKKKK.....",
    ]

    private static let fall: [String] = [
        "................................",
        "................................",
        "................................",
        "..........K...........K........",
        ".........KPK.........KPK.......",
        "........KPPPK.......KPPPK.......",
        "........KBBBKKKKKKKKKBBBK.......",
        ".......KBHHHHHHHBBBBBBBBBK......",
        ".......KBHHHBBBBBBBBBBBBBK......",
        ".......KBBBBBBBBBBBBBBBBBK......",
        ".......KBWWKKBBBBBBWWKKBBK......",
        ".......KBWWKKBBBBBBWWKKBBK......",
        ".......KBBBBBCCNNCCCBBBBBK......",
        ".......KBBBBBCKKKKKCBBBBBK......",
        ".......KBBBBBCCCCCCCBBBBBK......",
        ".......KSSSBBBBBBBBBBBSSSK......",
        "........KBBBBBBBBBBBBBBBK.......",
        "..........KBBBBBBBBBBBK........",
        "....KCBBBBKBBBBBBBBBBBKBBBBCK...",
        "....KKKKKKKBBBBBBBBBBBKKKKKKK...",
        "..........KBBBBBBBBBBBK........",
        "..........KBBBBBBBBBBBK........",
        "..........KBBBCCCCCBBBK........",
        "..........KBBBCCCCCBBBK........",
        "..........KKKKKKKKKKKKK........",
        ".......KBK.............KBK......",
        "......KCK...............KCK.....",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ]

    private static let squash: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        ".....KK.................KK......",
        "....KKKKKKKKKKKKKKKKKKKKKKKK....",
        "...KBHHHHHHHHBBBBBBBBBBBBBBK....",
        "...KBBBBKBKBBBBBBBBBBKBKBBBBK...",
        "...KBBBBBBBBBBBKKBBBBBBBBBBBK...",
        "...KBBBBBBBBBBBBBBBBBBBBBBBBK...",
        "..KCBBBBBBBBBBBBBBBBBBBBBBBBCK..",
        "...KSSSBBBBBBBBBBBBBBBBBBSSSK...",
        "....KKKKKKKKKKKKKKKKKKKKKKKK....",
    ]

    private static let carried: [String] = [
        "..........K...........K........",
        ".........KPK.........KPK.......",
        "........KPPPK.......KPPPK.......",
        "........KBBBKKKKKKKKKBBBK.......",
        ".......KBHHHHHHHBBBBBBBBBK......",
        ".......KBHHHBBBBBBBBBBBBBK......",
        ".......KBBBBBBBBBBBBBBBBBK......",
        ".......KBBBKKBBBBBBBKKBBBK......",
        ".......KBBBKKBBBBBBBKKBBBK......",
        ".......KBBBBBCCNNCCCBBBBBK......",
        ".......KBBBBBCKCCCKCBBBBBK......",
        ".......KBBBBBCCCCCCCBBBBBK......",
        ".......KSSSBBBBBBBBBBBSSSK......",
        "........KBBBBBBBBBBBBBBBK.......",
        "..........KKBBBBBBBBBKK........",
        "...........KBBBBBBBBBK.........",
        "...........KBBBBBBBBBK.........",
        "...........KBBCCCCCBBK.........",
        "...........KBBCCCCCBBK.........",
        "...........KBBCCCCCBBK.........",
        "...........KBBBBBBBBBK.........",
        "...........KBBBBBBBBBK.........",
        "...........KKBKBBBKBKK.........",
        "............KBK.T.KBK...........",
        "............KBK.T.KBK...........",
        "............KCK.T.KCK...........",
        "............KKK.T.KKK...........",
        "................K...............",
        "................................",
        "................................",
        "................................",
        "................................",
    ]

    private static let sniff1: [String] = [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "..KK............................",
        "..KBK...........................",
        "..KBK...........................",
        "..KTK...........................",
        "..KBK...........................",
        "..KBK...........................",
        "..KBK...........................",
        "..KBK...........................",
        "..KBK...........K...........K...",
        "...KKKKKKKKKK..KPK.........KPK..",
        "..KBBBTTBBTTB.KPPPK.......KPPPK.",
        "..KBBBBBBBBBB.KBBBKKKKKKKKKBBBK.",
        "..KBBBBBBBBBBKBHHHHHHHBBBBBBBBBK",
        "..KBBBBBBBBBBKBBBBBBBBBBBBBBBBBK",
        "..KBBBCCCCCCCKBBBBBBBBBBBBBBBBBK",
        "..KBBBCCCCCCCKBBBKKBBBBBBBKKBBBK",
        "..KKKKKKKKKKKKBBBKKBBBBBBBKKBBBK",
        "....SS.KBK...KBBBBBCCNNCCCBBBBBK",
        "....SS.KBK...KBBBBBCKCCCKCBBBBBK",
        "....SS.KBK...KBBBBBCCCCCCCBBBBBK",
        "....SS.KBK...KSSSBBBBBBBBBBBSSSK",
        "....SS.KBK....KBBBBBBBBBBBBBBBK.",
        ".......KCK......................",
        ".......KKK......................",
    ]

    private static func replacingRows(_ grid: [String], _ replacements: [Int: String]) -> [String] {
        var out = grid
        for (index, row) in replacements {
            out[index] = row
        }
        return out
    }

    private static func shiftedDown(_ grid: [String], _ amount: Int) -> [String] {
        let blank = String(repeating: ".", count: size)
        let rows = Array(repeating: blank, count: amount) + grid.dropLast(amount)
        return Array(rows)
    }

    private static let sit2 = replacingRows(sit1, [
        25: ".KK....KBBBBBBBBBBKBBBBK.......",
        26: ".KBK...KBBBBBBBBBBKBBBBK.......",
        27: ".KBK...KBBBBBBBBBBKBBBBK.......",
        28: "..KBK..KBBBBBBBBBBKBBBBK.......",
        29: "...KK..KBBBBBBBBBKCCCCCK.......",
        30: "....KK.KBBBBBBBBBKCCCCCK.......",
        31: ".......KKKKKKKKKKKKKKKKK.......",
    ])

    private static let blink = replacingRows(sit1, [
        12: ".......KBBBBBBBBBBBBBBBBBK......",
    ])

    private static let surprised = replacingRows(sit1, [
        12: ".......KBBBWWBBBBBBBWWBBBK......",
        15: ".......KBBBBBCCKKCCCBBBBBK......",
    ])

    private static let tongueOut = replacingRows(sit1, [
        15: ".......KBBBBBCKNNKCCBBBBBK......",
        16: ".......KBBBBBCCNNCCCBBBBBK......",
    ])

    private static let chew = replacingRows(sit1, [
        12: ".......KBBBBBBBBBBBBBBBBBK......",
        14: ".......KBCCCBCCNNCCCBCCCBK......",
    ])

    private static let hold = replacingRows(sit1, [
        25: ".......KBBBBBBBBBBKCCCCK.......",
        26: ".......KBBBBBBBBBBKCCCCK.......",
        27: ".......KBBBBBBBBBBBBBBBK.......",
        29: ".KBTBTBKBBBBBBBBBBBBBBBK.......",
        30: ".KBTBTBKBBBBBBBBBBBBBBBK.......",
    ])

    private static let walk2 = replacingRows(walk1, [
        25: "......KBKSS......SSKBK..........",
        26: "......KBKSS......SSKBK..........",
        27: "......KBKSS......SSKBK..........",
        28: "......KBKSS......SSKBK..........",
        29: "......KBKSS......SSKBK..........",
        30: "......KCK.........KCK...........",
        31: "......KKK.........KKK...........",
    ])

    private static let walk3 = replacingRows(walk1, [
        25: "....KBK.SS......KBK.SS..........",
        26: "....KBK.SS......KBK.SS..........",
        27: "....KBK.SS......KBK.SS..........",
        28: "....KBK.SS......KBK.SS..........",
        29: "....KBK.SS......KBK.SS..........",
        30: "....KCK.........KCK.............",
        31: "....KKK.........KKK.............",
    ])

    private static let sniff2 = replacingRows(sniff1, [
        30: ".......KCK..............S.......",
        31: ".......KKK...........S.........",
    ])

    private static let dig1 = replacingRows(sniff1, [
        30: ".......KCK..........W...........",
        31: ".......KKK.............S........",
    ])

    private static let dig2 = replacingRows(sniff1, [
        30: ".......KCK.............S........",
        31: ".......KKK..........W...........",
    ])

    static let frames: [String: [String]] = [
        "sit1": sit1,
        "sit2": sit2,
        "blink": blink,
        "surprised": surprised,
        "hold": hold,
        "tongueOut": tongueOut,
        "chew": chew,
        "walk1": walk1,
        "walk2": walk2,
        "walk3": walk3,
        "sleep1": sleep1,
        "sleep2": shiftedDown(sleep1, 1),
        "fall": fall,
        "squash": squash,
        "carried": carried,
        "sniff1": sniff1,
        "sniff2": sniff2,
        "dig1": dig1,
        "dig2": dig2,
    ]

    static let mouthAnchors: [String: CGPoint] = [
        "sit1": CGPoint(x: 16, y: 15),
        "sit2": CGPoint(x: 16, y: 15),
        "blink": CGPoint(x: 16, y: 15),
        "surprised": CGPoint(x: 16, y: 15),
        "hold": CGPoint(x: 21, y: 23),
        "walk1": CGPoint(x: 20, y: 13),
        "walk2": CGPoint(x: 20, y: 13),
        "walk3": CGPoint(x: 20, y: 13),
        "fall": CGPoint(x: 16, y: 13),
        "squash": CGPoint(x: 16, y: 27),
        "carried": CGPoint(x: 16, y: 10),
        "sniff1": CGPoint(x: 22, y: 26),
        "sniff2": CGPoint(x: 22, y: 26),
        "dig1": CGPoint(x: 22, y: 26),
        "dig2": CGPoint(x: 22, y: 26),
    ]

    static let idleKeys: Set<String> = ["sit1", "sit2", "blink", "hold", "surprised"]

    private static var cache: [String: CGImage] = [:]

    static func cg(look: CatLook, key: String, flipH: Bool = false, flipV: Bool = false, rotation: SpriteRotation = .none) -> CGImage {
        let cacheKey = "\(look.id)|\(key)|\(flipH)|\(flipV)|\(rotation)"
        if let hit = cache[cacheKey] {
            return hit
        }
        var grid: [String]
        if let custom = look.customGrid, idleKeys.contains(key) {
            grid = custom
        } else {
            grid = frames[key] ?? frames["sit1"]!
        }
        switch rotation {
        case .none:
            break
        case .clockwise:
            grid = rotatedCW(grid)
        case .counterclockwise:
            grid = rotatedCW(rotatedCW(rotatedCW(grid)))
        }
        let image = SpriteRenderer.cgImage(grid: grid, flipH: flipH, flipV: flipV, colors: look.coat.colorMap)
        cache[cacheKey] = image
        return image
    }

    private static func rotatedCW(_ grid: [String]) -> [String] {
        let cells = grid.map { Array($0) }
        let rows = cells.count
        let cols = cells.map { $0.count }.max() ?? 0
        var out: [[Character]] = Array(repeating: Array(repeating: ".", count: rows), count: cols)
        for r in 0..<rows {
            for c in 0..<cells[r].count {
                out[c][rows - 1 - r] = cells[r][c]
            }
        }
        return out.map { String($0) }
    }
}
