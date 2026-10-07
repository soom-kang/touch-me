import Foundation

struct SavedMapping: Codable {
    let schemaVersion: Int
    let displayUUID: String
    let vendor: Int
    let product: Int
    let locationID: UInt32
    let resumeMapping: Bool

    init(displayUUID: String, vendor: Int, product: Int, locationID: UInt32, resumeMapping: Bool) {
        self.schemaVersion = 1
        self.displayUUID = UUID(uuidString: displayUUID)?.uuidString ?? displayUUID
        self.vendor = vendor
        self.product = product
        self.locationID = locationID
        self.resumeMapping = resumeMapping
    }

    var isValid: Bool {
        schemaVersion == 1
            && UUID(uuidString: displayUUID) != nil
            && displayUUID.uppercased() != "00000000-0000-0000-0000-000000000000"
            && (1...0xFFFF).contains(vendor)
            && (0...0xFFFF).contains(product)
            && locationID > 0
    }
}

enum MappingPreferences {
    private static let key = "io.github.soom-kang.touchme.savedMapping.v1"

    static func load(defaults: UserDefaults = .standard) -> SavedMapping? {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedMapping.self, from: data),
              saved.isValid else { return nil }
        return SavedMapping(displayUUID: saved.displayUUID, vendor: saved.vendor, product: saved.product,
                            locationID: saved.locationID, resumeMapping: saved.resumeMapping)
    }

    @discardableResult
    static func save(_ saved: SavedMapping, defaults: UserDefaults = .standard) -> Bool {
        guard saved.isValid, let data = try? JSONEncoder().encode(saved) else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    @discardableResult
    static func setResumeMapping(_ resumeMapping: Bool, defaults: UserDefaults = .standard) -> Bool {
        guard let saved = load(defaults: defaults) else { return false }
        return save(SavedMapping(displayUUID: saved.displayUUID, vendor: saved.vendor, product: saved.product,
                                 locationID: saved.locationID, resumeMapping: resumeMapping), defaults: defaults)
    }
}
