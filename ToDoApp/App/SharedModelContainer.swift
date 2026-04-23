//
//  SharedModelContainer.swift
//  ToDoApp
//

import Foundation
import SwiftData

enum SharedModelContainer {
    private static let schema = Schema([Category.self, Item.self])
    private static let sharedConfigurationName = "ToDoSharedStore"
    private static let storeBasename = "\(sharedConfigurationName).store"

    static func make() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            sharedConfigurationName,
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeRecoveringShared() throws -> ModelContainer {
        do {
            return try make()
        } catch {
            try deleteSharedStoreFiles()
            return try make()
        }
    }

    static func makeLocal() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func deleteSharedStoreFiles() throws {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            return
        }

        let candidates = [
            groupURL.appendingPathComponent(storeBasename),
            groupURL.appendingPathComponent("\(storeBasename)-wal"),
            groupURL.appendingPathComponent("\(storeBasename)-shm"),
        ]

        for fileURL in candidates where FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
