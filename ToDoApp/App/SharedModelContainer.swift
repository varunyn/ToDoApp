//
//  SharedModelContainer.swift
//  ToDoApp
//

import Foundation
import SwiftData

enum SharedModelContainer {
    private static let schema = Schema([Category.self, Item.self])
    private static let sharedConfigurationName = "ToDoSharedStore"
    static func make() throws -> ModelContainer {
        try requireSharedContainer()
        let configuration = ModelConfiguration(
            sharedConfigurationName,
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeSharedWithoutCloudKit() throws -> ModelContainer {
        try requireSharedContainer()
        let configuration = ModelConfiguration(
            sharedConfigurationName,
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func requireSharedContainer() throws {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil else {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

}
