import Foundation

struct SharedList: Codable, Identifiable, Equatable, Sendable {
    var zoneName: String
    var ownerName: String
    var name: String
    var isOwner: Bool
    var canEdit = true
    var isAvailable = true
    var tasks: [SharedTask] = []

    var id: String { ownerName + "/" + zoneName }
    var visibleTasks: [SharedTask] {
        tasks.filter { !$0.isDeleted }.sorted {
            if $0.isDone != $1.isDone { return !$0.isDone }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id < $1.id
        }
    }
    var hasPendingChanges: Bool { tasks.contains { !$0.pendingFields.isEmpty } }

    /// Applies one CloudKit zone response. Incremental responses are deltas, so tasks
    /// absent from them remain cached; only a full response can reconcile absent IDs.
    mutating func applyRemoteChanges(
        tasks changedTasks: [SharedTask],
        deletedTaskIDs: Set<String>,
        isFullSnapshot: Bool
    ) {
        for remote in changedTasks {
            if let index = tasks.firstIndex(where: { $0.id == remote.id }) {
                tasks[index].merge(remote)
            } else {
                tasks.append(remote)
            }
        }

        if !deletedTaskIDs.isEmpty {
            tasks.removeAll { deletedTaskIDs.contains($0.id) }
        }

        if isFullSnapshot {
            let remoteIDs = Set(changedTasks.map(\.id))
            tasks.removeAll { !remoteIDs.contains($0.id) && $0.pendingFields.isEmpty }
        }
    }
}
