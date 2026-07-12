//
//  CategoryCustomization.swift
//  ToDoApp
//

import SwiftUI

enum CategoryIcon: String, CaseIterable, Identifiable {
    case briefcase = "briefcase.fill"
    case house = "house.fill"
    case heart = "heart.fill"
    case star = "star.fill"
    case book = "book.fill"
    case cart = "cart.fill"
    case calendar = "calendar"
    case figure = "figure.run"
    case lightbulb = "lightbulb.fill"
    case folder = "folder.fill"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .briefcase: "Briefcase"
        case .house: "House"
        case .heart: "Heart"
        case .star: "Star"
        case .book: "Book"
        case .cart: "Shopping"
        case .calendar: "Calendar"
        case .figure: "Fitness"
        case .lightbulb: "Ideas"
        case .folder: "Folder"
        }
    }
}

enum CategoryColor: Int, CaseIterable, Identifiable {
    case coral
    case blue
    case green
    case purple
    case orange
    case indigo

    var id: Int { rawValue }

    var colors: [Color] {
        switch self {
        case .coral: [Color(red: 1.0, green: 0.74, blue: 0.68), Color(red: 0.98, green: 0.56, blue: 0.52)]
        case .blue: [Color(red: 0.50, green: 0.90, blue: 1.0), Color(red: 0.23, green: 0.73, blue: 0.98)]
        case .green: [Color(red: 0.84, green: 1.0, blue: 0.53), Color(red: 0.69, green: 0.92, blue: 0.27)]
        case .purple: [Color(red: 0.78, green: 0.61, blue: 1.0), Color(red: 0.60, green: 0.42, blue: 0.96)]
        case .orange: [Color(red: 1.0, green: 0.82, blue: 0.50), Color(red: 0.98, green: 0.57, blue: 0.24)]
        case .indigo: [Color(red: 0.55, green: 0.65, blue: 1.0), Color(red: 0.32, green: 0.39, blue: 0.88)]
        }
    }
}

enum CategorySortRule: Int, CaseIterable, Identifiable {
    case manual
    case priority
    case name
    case completion

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .manual: "Manual"
        case .priority: "Priority"
        case .name: "Name"
        case .completion: "Completion status"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: "arrow.up.arrow.down"
        case .priority: "flag.fill"
        case .name: "textformat"
        case .completion: "checkmark.circle"
        }
    }
}
