//
//  TaskListFilter.swift
//  ToDoApp
//

import SwiftUI

enum TaskListFilter: Int, CaseIterable, Identifiable {
    case all = 0
    case completed = 1
    case pending = 2

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .completed: "Completed"
        case .pending: "Pending"
        }
    }
}
