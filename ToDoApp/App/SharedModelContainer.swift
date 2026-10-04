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
        let configuration = ModelConfiguration(
            sharedConfigurationName,
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeSharedWithoutCloudKit() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            sharedConfigurationName,
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeLocal() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

}
