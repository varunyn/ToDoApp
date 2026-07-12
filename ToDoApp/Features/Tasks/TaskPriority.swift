//
//  TaskPriority.swift
//  ToDoApp
//

import SwiftUI

enum TaskPriority: Int, CaseIterable, Identifiable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .none: "No priority"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "minus"
        case .low: "exclamationmark"
        case .medium: "exclamationmark.2"
        case .high: "exclamationmark.3"
        }
    }

    var tint: Color {
        switch self {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }
}
