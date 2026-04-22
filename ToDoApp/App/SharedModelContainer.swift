//
//  SharedModelContainer.swift
//  ToDoApp
//

import SwiftData

enum SharedModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([Category.self, Item.self])
        let configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.identifier))
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
