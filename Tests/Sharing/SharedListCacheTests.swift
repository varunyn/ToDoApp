import Foundation
import Testing
@testable import TokiSharing

struct SharedListCacheTests {
    @Test func legacyCacheUpgradesWithoutLosingPendingEdits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("shared-lists.json")
        let original = SharedList(zoneName: "zone", ownerName: "owner", name: "Groceries", isOwner: true,
                                  tasks: [SharedTask(id: "milk", title: "Milk", pendingFields: ["title"])])
        // Older releases wrote an array directly, without an envelope or tokens.
        try JSONEncoder().encode([original]).write(to: file)

        var upgraded = try SharedListCache.loadSnapshot(from: file)
        #expect(upgraded.lists == [original])
        #expect(upgraded.zoneTokens.isEmpty)
        upgraded.zoneTokens["private.zone"] = Data([0x04])
        try SharedListCache.save(upgraded, to: file)
        let restored = try SharedListCache.loadSnapshot(from: file)
        #expect(restored.lists == [original])
        #expect(restored.zoneTokens["private.zone"] == Data([0x04]))
    }

    @Test func cacheFileKeepsZoneTokenPairedWithItsListSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("shared-lists.json")
        let list = SharedList(zoneName: "zone", ownerName: "owner", name: "Groceries", isOwner: true,
                              tasks: [SharedTask(id: "milk", title: "Milk", pendingFields: ["title"])])
        let token = Data([0x01, 0x02, 0x03])
        let state = SharedListCache.Snapshot(lists: [list], zoneTokens: ["private.zone": token])

        try SharedListCache.save(state, to: file)
        let restored = try SharedListCache.loadSnapshot(from: file)

        #expect(restored.lists == [list])
        #expect(restored.zoneTokens == ["private.zone": token])
    }
}
