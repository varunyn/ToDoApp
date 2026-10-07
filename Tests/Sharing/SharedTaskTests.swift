import Foundation
import Testing
@testable import TokiSharing

struct SharedTaskTests {
    @Test func offlineTitleEditAndRemoteCompletionBothSurvive() {
        var local = SharedTask(id: "task", title: "Milk and eggs", pendingFields: ["title"])
        let remote = SharedTask(id: "task", title: "Milk", isDone: true, priority: 3)
        local.merge(remote)
        #expect(local.title == "Milk and eggs")
        #expect(local.isDone)
        #expect(local.priority == 3)
        #expect(local.pendingFields == ["title"])
    }

    @Test func remoteDeletionCannotBeUndoneByOfflineEdits() {
        var local = SharedTask(id: "task", title: "Offline edit", pendingFields: ["title"])
        local.merge(SharedTask(id: "task", title: "Removed", isDeleted: true))
        let list = SharedList(zoneName: "zone", ownerName: "wife", name: "Groceries", isOwner: false, tasks: [local])
        #expect(list.visibleTasks.isEmpty)
        #expect(list.hasPendingChanges == false)
    }

    @Test func incrementalZoneResponsePreservesUnchangedTasksAndAppliesDeletions() {
        var list = SharedList(zoneName: "zone", ownerName: "owner", name: "Groceries", isOwner: true, tasks: [
            SharedTask(id: "changed", title: "Local title", pendingFields: ["title"]),
            SharedTask(id: "unchanged", title: "Keep me"),
            SharedTask(id: "removed", title: "Remove me")
        ])

        list.applyRemoteChanges(
            tasks: [SharedTask(id: "changed", title: "Remote title", isDone: true)],
            deletedTaskIDs: ["removed"],
            isFullSnapshot: false
        )

        #expect(list.tasks.first(where: { $0.id == "changed" })?.title == "Local title")
        #expect(list.tasks.first(where: { $0.id == "changed" })?.isDone == true)
        #expect(list.tasks.first(where: { $0.id == "unchanged" })?.title == "Keep me")
        #expect(!list.tasks.contains(where: { $0.id == "removed" }))
    }

    @Test func fullZoneSnapshotRemovesOnlyAbsentTasksWithoutPendingEdits() {
        var list = SharedList(zoneName: "zone", ownerName: "owner", name: "Groceries", isOwner: true, tasks: [
            SharedTask(id: "present", title: "Current"),
            SharedTask(id: "stale", title: "Remove"),
            SharedTask(id: "pending", title: "Offline edit", pendingFields: ["title"])
        ])

        list.applyRemoteChanges(
            tasks: [SharedTask(id: "present", title: "Current")],
            deletedTaskIDs: [],
            isFullSnapshot: true
        )

        #expect(list.tasks.map(\.id).sorted() == ["pending", "present"])
        #expect(list.tasks.first(where: { $0.id == "pending" })?.pendingFields == ["title"])
    }

    @Test func uploadAcknowledgementRetainsNewerEditsWithoutResendingOldFields() {
        var task = SharedTask(title: "Milk", pendingFields: ["title"])
        let uploaded = task
        task.isDone = true
        task.pendingFields.insert("isDone")
        task.acknowledge(uploaded)
        #expect(task.pendingFields == ["isDone"])
        let completionUpload = task
        task.title = "Milk and eggs"
        task.pendingFields.insert("title")
        task.acknowledge(completionUpload)
        #expect(task.pendingFields == ["title"])
        task.acknowledge(task)
        #expect(task.pendingFields.isEmpty)
    }

    @Test func relaunchPreservesUnsentEditsAndDeletionMarkers() throws {
        let original = SharedList(zoneName: "zone", ownerName: "owner", name: "Groceries", isOwner: true, tasks: [
            SharedTask(id: "milk", title: "Milk", isDone: true, pendingFields: ["isDone"]),
            SharedTask(id: "eggs", title: "Eggs", isDeleted: true, pendingFields: ["isDeleted"])
        ])
        let saved = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(SharedList.self, from: saved)
        #expect(restored == original)
        #expect(restored.visibleTasks.map(\.id) == ["milk"])
        #expect(restored.hasPendingChanges)
    }

    @Test func completedTasksSortBelowUnfinishedTasks() {
        let list = SharedList(zoneName: "zone", ownerName: "owner", name: "Tasks", isOwner: true, tasks: [
            SharedTask(id: "done", title: "Done", isDone: true, order: 0),
            SharedTask(id: "later", title: "Later", order: 2),
            SharedTask(id: "next", title: "Next", order: 1)
        ])
        #expect(list.visibleTasks.map(\.id) == ["next", "later", "done"])
    }
}
