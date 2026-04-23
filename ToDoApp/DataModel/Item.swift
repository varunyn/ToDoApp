//
//  Item.swift
//  ToDoApp
//

import Foundation
import SwiftData

@Model
final class Item {
    #Index<Item>([\.order], [\.isDone])

    var widgetID: UUID
    var title: String
    var isDone: Bool
    var order: Int

    var category: Category?

    init(
        widgetID: UUID = UUID(),
        title: String = "",
        isDone: Bool = false,
        order: Int = 0,
        category: Category? = nil
    ) {
        self.widgetID = widgetID
        self.title = title
        self.isDone = isDone
        self.order = order
        self.category = category
    }
}
