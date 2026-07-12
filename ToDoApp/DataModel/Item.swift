//
//  Item.swift
//  ToDoApp
//

import Foundation
import SwiftData

@Model
final class Item {
    #Index<Item>([\.order], [\.isDone], [\.priorityRawValue])

    var widgetID: UUID
    var title: String
    var isDone: Bool
    var order: Int
    var priorityRawValue: Int = TaskPriority.none.rawValue

    var category: Category?

    init(
        widgetID: UUID = UUID(),
        title: String = "",
        isDone: Bool = false,
        order: Int = 0,
        priority: TaskPriority = .none,
        category: Category? = nil
    ) {
        self.widgetID = widgetID
        self.title = title
        self.isDone = isDone
        self.order = order
        self.priorityRawValue = priority.rawValue
        self.category = category
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }
}
