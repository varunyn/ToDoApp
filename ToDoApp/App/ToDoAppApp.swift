//
//  ToDoAppApp.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

@main
struct ToDoAppApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makePreferredContainer()
    }

    var body: some Scene {
        WindowGroup {
            CategoryListView()
                .tint(AppAppearance.accent)
        }
        .modelContainer(modelContainer)
    }

    private static func makePreferredContainer() -> ModelContainer {
        if let shared = try? SharedModelContainer.makeRecoveringShared() {
            return shared
        }
        if let inMemory = try? SharedModelContainer.makeInMemory() {
            return inMemory
        }
        fatalError("Could not open any SwiftData store configuration.")
    }
}
