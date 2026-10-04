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
        if let shared = try? SharedModelContainer.make() {
            return shared
        }
        if let sharedLocalOnly = try? SharedModelContainer.makeSharedWithoutCloudKit() {
            return sharedLocalOnly
        }
        if let local = try? SharedModelContainer.makeLocal() {
            return local
        }
        fatalError("Could not open any SwiftData store configuration.")
    }
}
