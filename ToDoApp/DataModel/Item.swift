//
//  Item.swift
//  ToDoApp
//

import Foundation
import SwiftData

@Model
final class Item {
    #Index<Item>([\.order], [\.isDone], [\.priorityRawValue])

    var widgetID: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var order: Int = 0
    // Optional so existing SwiftData stores can add this field through a lightweight migration.
    var createdAt: Date? = nil
    var priorityRawValue: Int = TaskPriority.none.rawValue

    var category: Category?

    init(
        widgetID: UUID = UUID(),
        title: String = "",
        isDone: Bool = false,
        order: Int = 0,
        createdAt: Date = .now,
        priority: TaskPriority = .none,
        category: Category? = nil
    ) {
        self.widgetID = widgetID
        self.title = title
        self.isDone = isDone
        self.order = order
        self.createdAt = createdAt
        self.priorityRawValue = priority.rawValue
        self.category = category
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }

    var pendingAgeLabel: String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: createdAt ?? .now)
        let today = calendar.startOfDay(for: .now)
        let days = max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0)

        switch days {
        case 0: return "Today"
        case 1: return "1d"
        default: return "\(days)d"
        }
    }
}
