import Foundation

enum SharedListCache {
    private static let legacyActiveAccountKey = "SharedListsAccount"
    private static let activeAccountMetadataKey = "SharedListsActiveAccountMetadata"

    private struct ActiveAccountMetadata: Codable {
        var account: String
        var identityToken: Data?
    }

    struct Snapshot: Codable, Sendable {
        var lists: [SharedList]
        /// Securely archived CKServerChangeToken values, keyed by database and zone identity.
        var zoneTokens: [String: Data]

        init(lists: [SharedList] = [], zoneTokens: [String: Data] = [:]) {
            self.lists = lists
            self.zoneTokens = zoneTokens
        }
    }

    static func fileURL(for account: String) throws -> URL {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeAccount = Data(account.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        return directory.appendingPathComponent("SharedLists-\(safeAccount).json")
    }

    static func load(account: String) throws -> [SharedList] {
        try loadSnapshot(account: account).lists
    }

    static func loadSnapshot(account: String) throws -> Snapshot {
        let url = try fileURL(for: account)
        return try loadSnapshot(from: url)
    }

    static func loadSnapshot(from url: URL) throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return Snapshot() }
        let data = try Data(contentsOf: url)
        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) { return snapshot }
        // Keep caches written by earlier versions usable; the next save upgrades the file.
        return Snapshot(lists: try JSONDecoder().decode([SharedList].self, from: data))
    }

    static func save(_ lists: [SharedList], account: String) throws {
        let previous = try loadSnapshot(account: account)
        try save(Snapshot(lists: lists, zoneTokens: previous.zoneTokens), account: account)
    }

    static func save(_ snapshot: Snapshot, account: String) throws {
        try save(snapshot, to: fileURL(for: account))
    }

    static func save(_ snapshot: Snapshot, to url: URL) throws {
        try JSONEncoder().encode(snapshot).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func zoneKey(database: String, ownerName: String, zoneName: String) -> String {
        [database, ownerName, zoneName].map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
    }

    static func setActiveAccount(_ account: String?, identityToken: (any NSCoding & NSCopying & NSObjectProtocol)? = nil) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        defaults?.removeObject(forKey: legacyActiveAccountKey)
        guard let account else {
            defaults?.removeObject(forKey: activeAccountMetadataKey)
            return
        }
        let archivedToken = identityToken.flatMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false)
        }
        let metadata = ActiveAccountMetadata(account: account, identityToken: archivedToken)
        guard let data = try? JSONEncoder().encode(metadata) else {
            defaults?.removeObject(forKey: activeAccountMetadataKey)
            return
        }
        defaults?.set(data, forKey: activeAccountMetadataKey)
    }

    static func activeLists() -> [SharedList] {
        guard let account = verifiedActiveAccount() else { return [] }
        return (try? load(account: account)) ?? []
    }

    static func activeSnapshot() -> (account: String, snapshot: Snapshot)? {
        guard let account = verifiedActiveAccount(),
              let snapshot = try? loadSnapshot(account: account) else { return nil }
        return (account, snapshot)
    }

    /// A cache can be shown offline only when the current iCloud identity token
    /// matches the token saved after a successful CloudKit identity lookup.
    private static func verifiedActiveAccount() -> String? {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier),
              let data = defaults.data(forKey: activeAccountMetadataKey),
              let metadata = try? JSONDecoder().decode(ActiveAccountMetadata.self, from: data),
              let archivedToken = metadata.identityToken,
              let currentToken = FileManager.default.ubiquityIdentityToken,
              let savedToken = decodeIdentityToken(archivedToken),
              savedToken.isEqual(currentToken) else { return nil }
        return metadata.account
    }

    private static func decodeIdentityToken(_ data: Data) -> NSObject? {
        guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        // The system identity token promises NSCoding, not NSSecureCoding.
        decoder.requiresSecureCoding = false
        decoder.decodingFailurePolicy = .setErrorAndReturn
        defer { decoder.finishDecoding() }
        return decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSObject
    }
}
