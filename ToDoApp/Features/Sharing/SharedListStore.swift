import CloudKit
import Observation
import SwiftData
import WidgetKit

@MainActor @Observable
final class SharedListStore {
    static let shared = SharedListStore()
    private(set) var lists: [SharedList] = []
    private(set) var isSyncing = false
    private(set) var isPublishing = false
    var errorMessage: String?

    @ObservationIgnored private var account: String?
    @ObservationIgnored private var zoneTokens: [String: Data] = [:]
    private var identityVerified = false
    private var reconciledListIDs: Set<String> = []
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherPass = false
    @ObservationIgnored private var invitationTask: Task<Void, Never>?

    private init() {
        guard let cached = SharedListCache.activeSnapshot() else { return }
        account = cached.account
        zoneTokens = cached.snapshot.zoneTokens
        // The last account that succeeded is a safe offline display choice, but its
        // cached permissions are not authority to edit until CloudKit verifies them.
        lists = cached.snapshot.lists.map { list in
            var list = list
            list.isAvailable = false
            list.canEdit = false
            return list
        }
    }

    var container: CKContainer {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String ?? ""
        return CKContainer(identifier: identifier)
    }

    func list(_ id: String) -> SharedList? { lists.first { $0.id == id } }

    func isAwaitingAccessVerification(for id: String) -> Bool {
        !identityVerified || !reconciledListIDs.contains(id)
    }

    func canEditList(_ id: String) -> Bool {
        guard !isAwaitingAccessVerification(for: id), let list = list(id) else { return false }
        return list.canEdit && list.isAvailable
    }

    func accountChanged() {
        epoch += 1
        syncTask?.cancel()
        invitationTask?.cancel()
        lists = []
        account = nil
        zoneTokens = [:]
        identityVerified = false
        reconciledListIDs = []
        SharedListCache.setActiveAccount(nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        requestSync()
    }

    func requestSync() {
        needsAnotherPass = true
        guard syncTask == nil, !isSyncing else { return }
        syncTask = Task {
            await refresh()
            syncTask = nil
            if needsAnotherPass { requestSync() }
        }
    }

    func refresh() async {
        guard !isSyncing else { needsAnotherPass = true; return }
        needsAnotherPass = false
        isSyncing = true
        defer {
            isSyncing = false
            if needsAnotherPass { requestSync() }
        }
        let session = epoch
        var hadError = false
        do {
            try await connect(session: session)
            let privateZones = try await container.privateCloudDatabase.allRecordZones()
            try check(session)
            let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
            try check(session)
            let zones = privateZones.filter { $0.zoneID.zoneName.hasPrefix("TokiList-") }.map { ($0, true) }
                + sharedZones.filter { $0.zoneID.zoneName.hasPrefix("TokiList-") }.map { ($0, false) }
            let existingIDs = Set(zones.map { $0.0.zoneID.ownerName + "/" + $0.0.zoneID.zoneName })
            // Retain a local copy when access is revoked, but never allow edits to it.
            var updated = lists
            for index in updated.indices {
                updated[index].isAvailable = existingIDs.contains(updated[index].id)
            }
            reconciledListIDs.formUnion(updated.filter { !$0.isAvailable }.map(\.id))
            try commit(updated)
            for (zone, isOwner) in zones {
                try Task.checkCancellation()
                do {
                    try await sync(zone: zone, isOwner: isOwner, session: session)
                } catch {
                    try check(session)
                    hadError = true
                    report(error)
                }
            }
            identityVerified = true
            if !hadError { errorMessage = nil }
        } catch is CancellationError {
            return
        } catch {
            if session == epoch { report(error) }
        }
    }

    private func connect(session: Int) async throws {
        let status = try await container.accountStatus()
        try check(session)
        guard status == .available else {
            if status == .noAccount || status == .restricted {
                lists = []
                account = nil
                zoneTokens = [:]
                identityVerified = false
                reconciledListIDs = []
                SharedListCache.setActiveAccount(nil)
            }
            throw SharingError.signIn
        }
        let identity = try await container.userRecordID().recordName
        try check(session)
        if identity != account || !identityVerified {
            let snapshot = try SharedListCache.loadSnapshot(account: identity)
            if identity != account {
                lists = snapshot.lists.map { list in
                    var list = list
                    list.isAvailable = false
                    return list
                }
                account = identity
                zoneTokens = snapshot.zoneTokens
                reconciledListIDs = []
            } else {
                // Recover original permissions from disk after the offline-safe copy
                // was shown. Actions remain guarded until this refresh reconciles zones.
                lists = snapshot.lists
                zoneTokens = snapshot.zoneTokens
                reconciledListIDs = []
            }
            identityVerified = true
            SharedListCache.setActiveAccount(identity, identityToken: FileManager.default.ubiquityIdentityToken)
        }
    }

    /// Publishing is retryable: the zone identifier is persisted before any network request.
    func publish(_ category: Category, context: ModelContext) async throws -> SharedList {
        guard !isSyncing else { throw SharingError.busy }
        isSyncing = true
        isPublishing = true
        defer {
            isSyncing = false
            isPublishing = false
            if needsAnotherPass { requestSync() }
        }
        let session = epoch
        try await connect(session: session)
        if category.pendingShareZoneName == nil {
            category.pendingShareZoneName = "TokiList-" + UUID().uuidString
            try PersistenceSupport.save(context)
        }
        guard let zoneName = category.pendingShareZoneName else { throw SharingError.missingList }
        let zone = CKRecordZone(zoneName: zoneName)
        if let existing = lists.first(where: { $0.zoneName == zoneName && $0.isOwner }) { return existing }
        let database = container.privateCloudDatabase
        _ = try await database.save(zone)
        try check(session)
        // Recover a completed publication after a crash, without overwriting collaborators' work.
        do {
            _ = try await database.record(for: CKRecord.ID(recordName: "list", zoneID: zone.zoneID))
            try check(session)
            try await sync(zone: zone, isOwner: true, session: session)
            if let existing = lists.first(where: { $0.zoneName == zoneName && $0.isOwner }) { return existing }
        } catch let error as CKError where error.code == .unknownItem {
            // No published root yet; the private SwiftData list remains authoritative.
        }
        var tasks = category.taskItems.map { item in
            SharedTask(id: item.widgetID.uuidString, title: item.title, isDone: item.isDone,
                       priority: item.priorityRawValue, order: item.order, createdAt: item.createdAt ?? .now)
        }
        for index in tasks.indices {
            tasks[index].pendingFields = ["title", "isDone", "priority", "order", "createdAt", "isDeleted"]
        }
        let list = SharedList(zoneName: zoneName, ownerName: zone.zoneID.ownerName,
                              name: category.name.isEmpty ? "Shared list" : category.name,
                              isOwner: true, tasks: tasks)
        // Upload tasks first and publish the root last so an incomplete upload is never discovered as a list.
        for task in tasks {
            let record = taskRecord(task, zoneID: zone.zoneID)
            let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
            guard let acknowledgement = result.saveResults[record.recordID] else { throw SharingError.unconfirmed }
            _ = try acknowledgement.get()
            try check(session)
        }
        let root = CKRecord(recordType: "TokiSharedList", recordID: CKRecord.ID(recordName: "list", zoneID: zone.zoneID))
        root["name"] = list.name as CKRecordValue
        _ = try await database.save(root)
        try check(session)
        try await sync(zone: zone, isOwner: true, session: session)
        guard let published = lists.first(where: { $0.id == list.id }) else { throw SharingError.missingList }
        return published
    }

    func share(for id: String) async throws -> CKShare {
        guard !isAwaitingAccessVerification(for: id) else { throw SharingError.busy }
        guard let list = list(id), list.isAvailable, identityVerified, reconciledListIDs.contains(id) else { throw SharingError.missingList }
        let session = epoch
        let database = database(for: list)
        let recordID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID(for: list))
        do {
            let record = try await database.record(for: recordID)
            try check(session)
            guard let share = record as? CKShare else { throw SharingError.missingList }
            return share
        } catch let error as CKError where error.code == .unknownItem && list.isOwner {
            let share = CKShare(recordZoneID: zoneID(for: list))
            share.publicPermission = .none
            share[CKShare.SystemFieldKey.title] = list.name as CKRecordValue
            let result = try await database.save(share)
            try check(session)
            guard let saved = result as? CKShare else { throw SharingError.missingList }
            return saved
        }
    }

    func accept(_ metadata: CKShare.Metadata) {
        // Queue invitations so a second incoming URL cannot cancel acceptance of the first.
        let previous = invitationTask
        let session = epoch
        invitationTask = Task {
            await previous?.value
            do {
                try check(session)
                guard metadata.containerIdentifier == container.containerIdentifier else { throw SharingError.wrongContainer }
                _ = try await container.accept(metadata)
                try check(session)
                requestSync()
            } catch is CancellationError {
                return
            } catch {
                if session == epoch { report(error) }
            }
        }
    }

    @discardableResult
    func addTask(to id: String, title: String, priority: Int) -> Bool {
        mutateList(id) { list in
            var task = SharedTask(title: title, priority: priority, order: (list.tasks.map(\.order).max() ?? -1) + 1)
            task.pendingFields = ["title", "isDone", "priority", "order", "createdAt", "isDeleted"]
            list.tasks.append(task)
        }
    }

    @discardableResult
    func editTask(listID: String, taskID: String, title: String? = nil, isDone: Bool? = nil, priority: Int? = nil, delete: Bool = false) -> Bool {
        guard identityVerified, reconciledListIDs.contains(listID),
              let current = list(listID), current.isAvailable, current.canEdit,
              current.tasks.contains(where: { $0.id == taskID && !$0.isDeleted }) else {
            errorMessage = "This task is no longer available to edit. Refresh the list to check your access."
            return false
        }
        return mutateList(listID) { list in
            guard let index = list.tasks.firstIndex(where: { $0.id == taskID && !$0.isDeleted }) else { return }
            if let title { list.tasks[index].title = title; list.tasks[index].pendingFields.insert("title") }
            if let isDone { list.tasks[index].isDone = isDone; list.tasks[index].pendingFields.insert("isDone") }
            if let priority { list.tasks[index].priority = priority; list.tasks[index].pendingFields.insert("priority") }
            if delete { list.tasks[index].isDeleted = true; list.tasks[index].pendingFields.insert("isDeleted") }
        }
    }

    func removeList(_ id: String) async throws {
        guard !isSyncing else { throw SharingError.busy }
        guard !isAwaitingAccessVerification(for: id) else { throw SharingError.busy }
        guard identityVerified, reconciledListIDs.contains(id), let list = list(id) else {
            throw SharingError.missingList
        }
        isSyncing = true
        defer {
            isSyncing = false
            if needsAnotherPass { requestSync() }
        }
        let session = epoch
        if list.isAvailable {
            _ = try await database(for: list).deleteRecordZone(withID: zoneID(for: list))
            try check(session)
        }
        let key = SharedListCache.zoneKey(database: list.isOwner ? "private" : "shared",
                                          ownerName: list.ownerName, zoneName: list.zoneName)
        let previousToken = zoneTokens.removeValue(forKey: key)
        do {
            try commit(lists.filter { $0.id != id })
            reconciledListIDs.remove(id)
        } catch {
            zoneTokens[key] = previousToken
            throw error
        }
    }

    func report(_ error: Error) {
        if let error = error as? CKError {
            switch error.code {
            case .notAuthenticated: errorMessage = "Sign into iCloud in Settings to share lists."
            case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited:
                errorMessage = "iCloud is unavailable. Your saved edits will sync when the connection returns."
            case .quotaExceeded: errorMessage = "There isn’t enough iCloud storage to sync this list. Free up some storage and try again."
            case .permissionFailure: errorMessage = "You no longer have permission to edit this list. Refresh to check your access."
            case .badContainer, .missingEntitlement: errorMessage = "iCloud sharing isn’t configured for this build. Please contact the developer."
            default: errorMessage = "The list couldn’t sync with iCloud. Your saved edits are still on this device. Please try again."
            }
        } else {
            errorMessage = (error as? SharingError)?.errorDescription ?? "The shared list couldn’t be saved. Please try again."
        }
    }

    @discardableResult
    private func mutateList(_ id: String, mutation: (inout SharedList) -> Void) -> Bool {
        guard identityVerified, reconciledListIDs.contains(id),
              let index = lists.firstIndex(where: { $0.id == id }), lists[index].canEdit, lists[index].isAvailable else { return false }
        var updated = lists
        mutation(&updated[index])
        do { try commit(updated); requestSync(); return true } catch { report(error); return false }
    }

    private func commit(_ updated: [SharedList]) throws {
        guard let account else { throw SharingError.signIn }
        try SharedListCache.save(.init(lists: updated, zoneTokens: zoneTokens), account: account)
        lists = updated
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private func sync(zone: CKRecordZone, isOwner: Bool, session: Int) async throws {
        let database = isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
        let id = zone.zoneID.ownerName + "/" + zone.zoneID.zoneName
        let key = SharedListCache.zoneKey(database: isOwner ? "private" : "shared",
                                          ownerName: zone.zoneID.ownerName, zoneName: zone.zoneID.zoneName)
        let priorToken = decodeToken(zoneTokens[key])
        let changes: ZoneChanges
        do {
            changes = try await fetchChanges(database: database, zoneID: zone.zoneID,
                                             since: priorToken, isFullSnapshot: priorToken == nil, session: session)
        } catch let error as CKError where error.code == .changeTokenExpired && priorToken != nil {
            // A stale token invalidates the delta as a whole. Discard it and rebuild
            // from a full zone response before advancing the persisted token.
            changes = try await fetchChanges(database: database, zoneID: zone.zoneID,
                                             since: nil, isFullSnapshot: true, session: session)
        }
        try check(session)

        let currentCached = lists.first { $0.id == id }
        var merged = currentCached ?? SharedList(zoneName: zone.zoneID.zoneName,
                                                  ownerName: zone.zoneID.ownerName,
                                                  name: "Shared list", isOwner: isOwner)
        let root = changes.records.values.first { $0.recordType == "TokiSharedList" }
        let rootWasDeleted = changes.deletedRecordTypes.contains { $0.value == "TokiSharedList" }
        let rootIsMissing = rootWasDeleted || (changes.isFullSnapshot && root == nil)
        guard root != nil || currentCached != nil else { return }
        if let name = root?["name"] as? String { merged.name = name }
        merged.isOwner = isOwner
        merged.isAvailable = !rootIsMissing

        if isOwner {
            merged.canEdit = true
        } else if let share = changes.records.values.compactMap({ $0 as? CKShare }).first {
            merged.canEdit = share.currentUserParticipant?.permission == .readWrite
        } else if changes.deletedRecordTypes.values.contains(where: { $0 == CKRecord.SystemType.share }) || rootWasDeleted {
            merged.canEdit = false
        } else if changes.isFullSnapshot {
            merged.canEdit = false
        }

        let remoteTasks = changes.records.values
            .filter { $0.recordType == "TokiSharedTask" }
            .map(decodeTask)
        let deletedTaskIDs = Set(changes.deletedRecordTypes.compactMap { recordID, type in
            type == "TokiSharedTask" ? recordID.recordName : nil
        })
        merged.applyRemoteChanges(tasks: remoteTasks, deletedTaskIDs: deletedTaskIDs,
                                  isFullSnapshot: changes.isFullSnapshot)

        if rootIsMissing { merged.canEdit = false }
        let pending = merged.canEdit ? merged.tasks.filter { !$0.pendingFields.isEmpty } : []
        var tombstonedTasks: [String: SharedTask] = [:]
        if !pending.isEmpty {
            let recordIDs = pending.map { CKRecord.ID(recordName: $0.id, zoneID: zone.zoneID) }
            let fetched = try await database.records(for: recordIDs)
            try check(session)
            for task in pending {
                let recordID = CKRecord.ID(recordName: task.id, zoneID: zone.zoneID)
                let record: CKRecord
                if let result = fetched[recordID] {
                    do {
                        record = try result.get()
                        if (record["isDeleted"] as? NSNumber)?.boolValue == true {
                            let tombstone = decodeTask(record)
                            tombstonedTasks[task.id] = tombstone
                            if let index = merged.tasks.firstIndex(where: { $0.id == task.id }) { merged.tasks[index].merge(tombstone) }
                            continue
                        }
                    } catch let error as CKError where error.code == .unknownItem {
                        record = CKRecord(recordType: "TokiSharedTask", recordID: recordID)
                    }
                } else {
                    throw SharingError.unconfirmed
                }
                var uploadRecord = record
                var didUpload = false
                for attempt in 0..<3 {
                    if (uploadRecord["isDeleted"] as? NSNumber)?.boolValue == true {
                        let tombstone = decodeTask(uploadRecord)
                        tombstonedTasks[task.id] = tombstone
                        if let index = merged.tasks.firstIndex(where: { $0.id == task.id }) { merged.tasks[index].merge(tombstone) }
                        didUpload = true
                        break
                    }
                    apply(task, to: uploadRecord, fields: task.pendingFields)
                    do {
                        let result = try await database.modifyRecords(saving: [uploadRecord], deleting: [], savePolicy: .ifServerRecordUnchanged)
                        guard let acknowledgement = result.saveResults[recordID] else { throw SharingError.unconfirmed }
                        _ = try acknowledgement.get()
                        try check(session)
                        didUpload = true
                        break
                    } catch let error as CKError where error.code == .serverRecordChanged && attempt < 2 {
                        uploadRecord = try await database.record(for: recordID)
                        try check(session)
                    }
                }
                guard didUpload else { throw SharingError.unconfirmed }
                if let index = merged.tasks.firstIndex(where: { $0.id == task.id }) {
                    if (uploadRecord["isDeleted"] as? NSNumber)?.boolValue != true {
                        merged.tasks[index].acknowledge(task)
                    }
                }
            }
        }

        // Re-read after network awaits so edits made while this zone was syncing
        // remain in the outbox. Reapplying the delta respects any newly pending fields.
        var finalList = lists.first { $0.id == id } ?? merged
        finalList.name = merged.name
        finalList.isOwner = merged.isOwner
        finalList.canEdit = merged.canEdit
        finalList.isAvailable = merged.isAvailable
        finalList.applyRemoteChanges(tasks: remoteTasks, deletedTaskIDs: deletedTaskIDs,
                                    isFullSnapshot: changes.isFullSnapshot)
        for tombstone in tombstonedTasks.values {
            if let index = finalList.tasks.firstIndex(where: { $0.id == tombstone.id }) {
                finalList.tasks[index].merge(tombstone)
            }
        }
        for uploaded in pending {
            if !tombstonedTasks.keys.contains(uploaded.id),
               let index = finalList.tasks.firstIndex(where: { $0.id == uploaded.id }) {
                finalList.tasks[index].acknowledge(uploaded)
            }
        }
        var updated = lists.filter { $0.id != id }
        updated.append(finalList)
        let previousToken = zoneTokens[key]
        zoneTokens[key] = try encodeToken(changes.changeToken)
        do {
            try commit(updated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
            reconciledListIDs.insert(id)
        } catch {
            // The old token remains in the on-disk snapshot unless list changes and
            // their corresponding cursor were committed together.
            zoneTokens[key] = previousToken
            throw error
        }
    }

    private func fetchChanges(database: CKDatabase, zoneID: CKRecordZone.ID,
                              since startingToken: CKServerChangeToken?, isFullSnapshot: Bool,
                              session: Int) async throws -> ZoneChanges {
        var token = startingToken
        var records: [CKRecord.ID: CKRecord] = [:]
        var deletedRecordTypes: [CKRecord.ID: String] = [:]
        while true {
            let page = try await database.recordZoneChanges(inZoneWith: zoneID, since: token,
                                                            desiredKeys: nil, resultsLimit: nil)
            try check(session)
            for (id, result) in page.modificationResultsByID {
                records[id] = try result.get().record
                deletedRecordTypes[id] = nil
            }
            for deletion in page.deletions {
                records[deletion.recordID] = nil
                deletedRecordTypes[deletion.recordID] = deletion.recordType
            }
            token = page.changeToken
            if !page.moreComing { break }
        }
        guard let token else { throw SharingError.unconfirmed }
        return ZoneChanges(records: records, deletedRecordTypes: deletedRecordTypes,
                           changeToken: token, isFullSnapshot: isFullSnapshot)
    }

    private func decodeToken(_ data: Data?) -> CKServerChangeToken? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func encodeToken(_ token: CKServerChangeToken) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func decodeTask(_ record: CKRecord) -> SharedTask {
        SharedTask(id: record.recordID.recordName, title: record["title"] as? String ?? "Untitled task",
                   isDone: (record["isDone"] as? NSNumber)?.boolValue ?? false,
                   priority: (record["priority"] as? NSNumber)?.intValue ?? 0,
                   order: (record["order"] as? NSNumber)?.intValue ?? 0,
                   createdAt: record["createdAt"] as? Date ?? .now,
                   isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false)
    }

    private func taskRecord(_ task: SharedTask, zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: "TokiSharedTask", recordID: CKRecord.ID(recordName: task.id, zoneID: zoneID))
        apply(task, to: record, fields: ["title", "isDone", "priority", "order", "createdAt", "isDeleted"])
        return record
    }

    private func apply(_ task: SharedTask, to record: CKRecord, fields: Set<String>) {
        if fields.contains("title") { record["title"] = task.title as CKRecordValue }
        if fields.contains("isDone") { record["isDone"] = NSNumber(value: task.isDone) }
        if fields.contains("priority") { record["priority"] = NSNumber(value: task.priority) }
        if fields.contains("order") { record["order"] = NSNumber(value: task.order) }
        if fields.contains("createdAt") { record["createdAt"] = task.createdAt as CKRecordValue }
        if fields.contains("isDeleted") { record["isDeleted"] = NSNumber(value: task.isDeleted) }
    }

    private func zoneID(for list: SharedList) -> CKRecordZone.ID { CKRecordZone.ID(zoneName: list.zoneName, ownerName: list.ownerName) }
    private func database(for list: SharedList) -> CKDatabase { list.isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase }
    private func check(_ session: Int) throws {
        try Task.checkCancellation()
        guard epoch == session else { throw CancellationError() }
    }
}

private struct ZoneChanges {
    var records: [CKRecord.ID: CKRecord]
    var deletedRecordTypes: [CKRecord.ID: String]
    var changeToken: CKServerChangeToken
    var isFullSnapshot: Bool
}

private enum SharingError: LocalizedError {
    case signIn, busy, missingList, wrongContainer, unconfirmed
    var errorDescription: String? {
        switch self {
        case .signIn: "Sign into iCloud in Settings to share lists."
        case .busy: "The lists are syncing. Please try again in a moment."
        case .missingList: "This shared list is no longer available. Refresh and try again."
        case .wrongContainer: "This invitation belongs to a different app."
        case .unconfirmed: "iCloud hasn’t confirmed this upload. Your saved edits will be retried."
        }
    }
}
