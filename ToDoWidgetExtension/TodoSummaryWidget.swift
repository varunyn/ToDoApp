//
//  TodoSummaryWidget.swift
//  ToDoWidgetExtension
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct TodoSummaryEntry: TimelineEntry {
    let date: Date
    let openTaskCount: Int
    let categoryCount: Int
    let pendingTasks: [WidgetPendingTask]
}

struct WidgetPendingTask: Hashable {
    let widgetID: UUID
    let title: String
}

struct TodoSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoSummaryEntry {
        TodoSummaryEntry(
            date: .now,
            openTaskCount: 3,
            categoryCount: 2,
            pendingTasks: [
                WidgetPendingTask(widgetID: UUID(), title: "Buy milk"),
                WidgetPendingTask(widgetID: UUID(), title: "Call back"),
                WidgetPendingTask(widgetID: UUID(), title: "Review notes"),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoSummaryEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoSummaryEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> TodoSummaryEntry {
        guard let container = try? SharedModelContainer.make() else {
            return TodoSummaryEntry(date: .now, openTaskCount: 0, categoryCount: 0, pendingTasks: [])
        }
        let context = ModelContext(container)
        let openItems = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { !$0.isDone }))) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let sorted = openItems.sorted { $0.order < $1.order }
        let tasks = sorted.prefix(5).map { item in
            let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return WidgetPendingTask(
                widgetID: item.widgetID,
                title: t.isEmpty ? "Untitled task" : t
            )
        }
        return TodoSummaryEntry(
            date: .now,
            openTaskCount: openItems.count,
            categoryCount: categories.count,
            pendingTasks: Array(tasks)
        )
    }
}

struct ToggleTaskDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Task Done"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard
            let uuid = UUID(uuidString: taskID),
            let container = try? SharedModelContainer.make()
        else {
            return .result()
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.widgetID == uuid })
        if let item = try? context.fetch(descriptor).first {
            item.isDone.toggle()
            try? context.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        }

        return .result()
    }
}

struct TodoSummaryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodoSummaryEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To-Do")
                .font(.headline)
            Text("^[\(entry.openTaskCount) open task](inflect: true)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("^[\(entry.categoryCount) category](inflect: true)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("To-Do")
                    .font(.headline)
                Text("^[\(entry.openTaskCount) open task](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("^[\(entry.categoryCount) category](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Next")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if entry.pendingTasks.isEmpty {
                    Text("All caught up")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(entry.pendingTasks, id: \.widgetID) { task in
                        Button(intent: ToggleTaskDoneIntent(taskID: task.widgetID.uuidString)) {
                            HStack(spacing: 6) {
                                Image(systemName: "circle")
                                    .font(.caption2)
                                Text(task.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

struct TodoSummaryWidget: Widget {
    let kind: String = "TodoSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoSummaryProvider()) { entry in
            TodoSummaryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("To-Do summary")
        .description("Open tasks and categories at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    TodoSummaryWidget()
} timeline: {
    TodoSummaryEntry(
        date: .now,
        openTaskCount: 4,
        categoryCount: 2,
        pendingTasks: [
            WidgetPendingTask(widgetID: UUID(), title: "One"),
            WidgetPendingTask(widgetID: UUID(), title: "Two"),
        ]
    )
}
