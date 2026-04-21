//
//  Category.swift
//  ToDoApp
//

import Foundation
import SwiftData

@Model
final class Category {
    #Index<Category>([\.order])

    var name: String
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \Item.category)
    var items: [Item]

    init(name: String = "", order: Int = 0, items: [Item] = []) {
        self.name = name
        self.order = order
        self.items = items
    }
}
