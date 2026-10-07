//
//  Category.swift
//  ToDoApp
//

import Foundation
import SwiftData

@Model
final class Category {
    #Index<Category>([\.order], [\.sortRuleRawValue])

    var name: String = ""
    var order: Int = 0
    var iconName: String = CategoryIcon.briefcase.rawValue
    var colorIndex: Int = CategoryColor.coral.rawValue
    var sortRuleRawValue: Int = CategorySortRule.manual.rawValue
    var goal: Int?

    @Relationship(deleteRule: .cascade, inverse: \Item.category)
    var items: [Item]? = []

    // The original private data is retained after publication as a recovery copy.
    var sharedZoneName: String? = nil
    var pendingShareZoneName: String? = nil

    var taskItems: [Item] { items ?? [] }

    init(
        name: String = "",
        order: Int = 0,
        icon: CategoryIcon = .briefcase,
        color: CategoryColor = .coral,
        sortRule: CategorySortRule = .manual,
        goal: Int? = nil,
        items: [Item] = []
    ) {
        self.name = name
        self.order = order
        self.iconName = icon.rawValue
        self.colorIndex = color.rawValue
        self.sortRuleRawValue = sortRule.rawValue
        self.goal = goal
        self.items = items
    }

    var icon: CategoryIcon {
        get { CategoryIcon(rawValue: iconName) ?? .briefcase }
        set { iconName = newValue.rawValue }
    }

    var color: CategoryColor {
        get { CategoryColor(rawValue: colorIndex) ?? .coral }
        set { colorIndex = newValue.rawValue }
    }

    var sortRule: CategorySortRule {
        get { CategorySortRule(rawValue: sortRuleRawValue) ?? .manual }
        set { sortRuleRawValue = newValue.rawValue }
    }
}
