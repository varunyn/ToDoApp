//
//  Item.swift
//  ToDoApp
//

import Foundation
import SwiftData

@Model
final class Item {
    #Index<Item>([\.order], [\.isDone])

    var title: String
    var isDone: Bool
    var order: Int

    var category: Category?

    init(title: String = "", isDone: Bool = false, order: Int = 0, category: Category? = nil) {
        self.title = title
        self.isDone = isDone
        self.order = order
        self.category = category
    }
}
