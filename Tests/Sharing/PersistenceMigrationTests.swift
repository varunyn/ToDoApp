import Foundation
import SwiftData
import Testing
@testable import TokiSharing

struct PersistenceMigrationTests {
    @Test @MainActor func existingListSurvivesCloudCompatibleSchemaUpgrade() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("tasks.store")
        let originalTaskID = UUID()
        try autoreleasepool {
            let schema = Schema([OriginalSchema.Category.self, OriginalSchema.Item.self])
            let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let category = OriginalSchema.Category(name: "Groceries")
            let task = OriginalSchema.Item(widgetID: originalTaskID, title: "Milk", category: category)
            container.mainContext.insert(category)
            container.mainContext.insert(task)
            try container.mainContext.save()
        }
        let schema = Schema([TokiSharing.Category.self, TokiSharing.Item.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let upgraded = try ModelContainer(for: schema, configurations: [configuration])
        let categories = try upgraded.mainContext.fetch(FetchDescriptor<TokiSharing.Category>())
        let category = try #require(categories.first)
        #expect(categories.count == 1)
        #expect(category.name == "Groceries")
        #expect(category.sharedZoneName == nil)
        #expect(category.pendingShareZoneName == nil)
        let task = try #require(category.taskItems.first)
        #expect(task.title == "Milk")
        #expect(task.widgetID == originalTaskID)
        #expect(task.category === category)
    }
}

// The previously shipped schema: required relationships and no sharing metadata.
// This fixture deliberately stays fixed to protect migration of existing on-device data.
private enum OriginalSchema {
    @Model final class Category {
        #Index<Category>([\.order], [\.sortRuleRawValue])
        var name: String
        var order: Int
        var iconName: String = "briefcase.fill"
        var colorIndex: Int = 0
        var sortRuleRawValue: Int = 0
        var goal: Int?
        @Relationship(deleteRule: .cascade, inverse: \Item.category)
        var items: [Item]
        init(name: String) { self.name = name; order = 0; items = [] }
    }

    @Model final class Item {
        #Index<Item>([\.order], [\.isDone], [\.priorityRawValue])
        var widgetID: UUID
        var title: String
        var isDone: Bool
        var order: Int
        var createdAt: Date? = nil
        var priorityRawValue: Int = 0
        var category: Category?
        init(widgetID: UUID, title: String, category: Category) {
            self.widgetID = widgetID; self.title = title; self.category = category
            isDone = false; order = 0; createdAt = .now
        }
    }
}
