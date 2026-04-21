//
//  ToDoAppApp.swift
//  ToDoApp
//

import SwiftUI
import SwiftData

@main
struct ToDoAppApp: App {
    var body: some Scene {
        WindowGroup {
            CategoryListView()
                .tint(AppAppearance.accent)
        }
        .modelContainer(for: [Category.self, Item.self], inMemory: false)
    }
}
