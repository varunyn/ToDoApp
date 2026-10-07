import Foundation

/// A task's pending fields are the durable outbox. Sync never overwrites unrelated edits.
struct SharedTask: Codable, Identifiable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var title: String
    var isDone = false
    var priority = 0
    var order = 0
    var createdAt = Date.now
    var isDeleted = false
    var pendingFields: Set<String> = []
    mutating func acknowledge(_ uploaded: SharedTask) {
        // Clear each uploaded field independently; an edit during the request stays queued.
        for field in uploaded.pendingFields {
            let unchanged: Bool
            switch field {
            case "title": unchanged = title == uploaded.title
            case "isDone": unchanged = isDone == uploaded.isDone
            case "priority": unchanged = priority == uploaded.priority
            case "order": unchanged = order == uploaded.order
            case "createdAt": unchanged = createdAt == uploaded.createdAt
            case "isDeleted": unchanged = isDeleted == uploaded.isDeleted
            default: unchanged = false
            }
            if unchanged { pendingFields.remove(field) }
        }
    }

    mutating func merge(_ remote: SharedTask) {
        if remote.isDeleted {
            self = remote // Deletion wins, including over an offline edit.
            return
        }
        if !pendingFields.contains("title") { title = remote.title }
        if !pendingFields.contains("isDone") { isDone = remote.isDone }
        if !pendingFields.contains("priority") { priority = remote.priority }
        if !pendingFields.contains("order") { order = remote.order }
        if !pendingFields.contains("isDeleted") { isDeleted = remote.isDeleted }
        createdAt = remote.createdAt
    }
}
