import AppKit

final class CatLook: Equatable {
    let id: String
    let name: String
    let coat: Coat
    let customGrid: [String]?

    init(id: String, name: String, coat: Coat, customGrid: [String]? = nil) {
        self.id = id
        self.name = name
        self.coat = coat
        self.customGrid = customGrid
    }

    static func == (lhs: CatLook, rhs: CatLook) -> Bool {
        lhs.id == rhs.id
    }

    static func coat(_ coat: Coat) -> CatLook {
        CatLook(id: "coat-\(coat.id)", name: coat.name, coat: coat)
    }

    static func guest(_ coat: Coat) -> CatLook {
        CatLook(id: "guest-\(coat.id)", name: coat.name, coat: coat)
    }
}

struct CatSpec: Equatable {
    let name: String
    let coatId: String
    let customGrid: [String]?

    var look: CatLook {
        let coat = Coat.by(id: coatId)
        if let customGrid {
            return CatLook(id: "custom-\(name)-\(coatId)", name: name, coat: coat, customGrid: customGrid)
        }
        return CatLook(id: "coat-\(coatId)-\(name)", name: name, coat: coat)
    }

    var dictionary: [String: Any] {
        var out: [String: Any] = ["name": name, "coatId": coatId]
        if let customGrid { out["customGrid"] = customGrid }
        return out
    }

    init(name: String, coatId: String, customGrid: [String]? = nil) {
        self.name = name
        self.coatId = coatId
        self.customGrid = customGrid
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let coatId = dictionary["coatId"] as? String else { return nil }
        self.name = name
        self.coatId = coatId
        self.customGrid = dictionary["customGrid"] as? [String]
    }
}

enum CatStore {
    private static let key = "mochi.cats.v1"

    static func load() -> [CatSpec] {
        guard let raw = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else {
            return [CatSpec(name: "Mochi", coatId: "grey")]
        }
        let specs = raw.compactMap { CatSpec(dictionary: $0) }
        return specs.isEmpty ? [CatSpec(name: "Mochi", coatId: "grey")] : specs
    }

    static func save(_ specs: [CatSpec]) {
        UserDefaults.standard.set(specs.map { $0.dictionary }, forKey: key)
    }
}
