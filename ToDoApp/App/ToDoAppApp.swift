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
        do {
            modelContainer = try SharedModelContainer.make()
        } catch {
            fatalError("Could not open shared SwiftData store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            CategoryListView()
                .tint(AppAppearance.accent)
        }
        .modelContainer(modelContainer)
    }
}
