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
    let hasTransientCompletions: Bool
}

struct WidgetPendingTask: Hashable {
    let widgetID: UUID
    let title: String
    let isRecentlyCompleted: Bool
}

struct TodoSummaryProvider: TimelineProvider {
    private enum TransientCompletionStore {
        static let defaultsKey = "widget.transientCompletions"
        static let lifetime: TimeInterval = 3.0
    }

    func placeholder(in context: Context) -> TodoSummaryEntry {
        TodoSummaryEntry(
            date: .now,
            openTaskCount: 3,
            categoryCount: 2,
            pendingTasks: [
                WidgetPendingTask(widgetID: UUID(), title: "Buy milk", isRecentlyCompleted: false),
                WidgetPendingTask(widgetID: UUID(), title: "Call back", isRecentlyCompleted: false),
                WidgetPendingTask(widgetID: UUID(), title: "Review notes", isRecentlyCompleted: false),
            ],
            hasTransientCompletions: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoSummaryEntry) -> Void) {
        completion(loadEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoSummaryEntry>) -> Void) {
        let now = Date()
        let firstEntry = loadEntry(at: now)
        if firstEntry.hasTransientCompletions {
            let secondDate = now.addingTimeInterval(TransientCompletionStore.lifetime + 0.4)
            let secondEntry = loadEntry(at: secondDate)
            completion(Timeline(entries: [firstEntry, secondEntry], policy: .atEnd))
        } else {
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
            completion(Timeline(entries: [firstEntry], policy: .after(next)))
        }
    }

    private func loadEntry(at currentDate: Date) -> TodoSummaryEntry {
        guard let container = try? SharedModelContainer.make() else {
            return TodoSummaryEntry(
                date: currentDate,
                openTaskCount: 0,
                categoryCount: 0,
                pendingTasks: [],
                hasTransientCompletions: false
            )
        }
        let context = ModelContext(container)
        let openItems = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { !$0.isDone }))) ?? []
        let completedItems = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.isDone }))) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let transientCompletions = loadTransientCompletions(currentDate: currentDate)

        let recentCompletedTasks = completedItems
            .filter { transientCompletions[$0.widgetID] != nil }
            .sorted { $0.order < $1.order }
            .map { item in
                let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return WidgetPendingTask(
                    widgetID: item.widgetID,
                    title: t.isEmpty ? "Untitled task" : t,
                    isRecentlyCompleted: true
                )
            }

        let pendingTasks = openItems.sorted { $0.order < $1.order }.map { item in
            let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return WidgetPendingTask(
                widgetID: item.widgetID,
                title: t.isEmpty ? "Untitled task" : t,
                isRecentlyCompleted: false
            )
        }

        let tasks = Array((recentCompletedTasks + pendingTasks).prefix(5))
        return TodoSummaryEntry(
            date: currentDate,
            openTaskCount: openItems.count,
            categoryCount: categories.count,
            pendingTasks: tasks,
            hasTransientCompletions: !recentCompletedTasks.isEmpty
        )
    }

    private func loadTransientCompletions(currentDate: Date) -> [UUID: Date] {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? UserDefaults.standard
        guard
            let raw = defaults.dictionary(forKey: TransientCompletionStore.defaultsKey) as? [String: TimeInterval]
        else {
            return [:]
        }

        var valid: [UUID: Date] = [:]
        var hasExpiredEntries = false

        for (idString, timestamp) in raw {
            guard let id = UUID(uuidString: idString) else {
                hasExpiredEntries = true
                continue
            }
            let date = Date(timeIntervalSince1970: timestamp)
            if currentDate.timeIntervalSince(date) <= TransientCompletionStore.lifetime {
                valid[id] = date
            } else {
                hasExpiredEntries = true
            }
        }

        if hasExpiredEntries {
            let cleaned = Dictionary(uniqueKeysWithValues: valid.map { ($0.key.uuidString, $0.value.timeIntervalSince1970) })
            defaults.set(cleaned, forKey: TransientCompletionStore.defaultsKey)
        }

        return valid
    }
}

struct ToggleTaskDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Task Done"
    private enum TransientCompletionStore {
        static let defaultsKey = "widget.transientCompletions"
    }

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
            let willBeDone = !item.isDone
            item.isDone.toggle()
            try? context.save()
            updateTransientCompletion(id: uuid, shouldAdd: willBeDone)
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        }

        return .result()
    }

    private func updateTransientCompletion(id: UUID, shouldAdd: Bool) {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return }
        var raw = defaults.dictionary(forKey: TransientCompletionStore.defaultsKey) as? [String: TimeInterval] ?? [:]
        if shouldAdd {
            raw[id.uuidString] = Date().timeIntervalSince1970
        } else {
            raw.removeValue(forKey: id.uuidString)
        }
        defaults.set(raw, forKey: TransientCompletionStore.defaultsKey)
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("To-Do")
                    .font(.headline)
                HStack(spacing: 10) {
                    Label("^[\(entry.openTaskCount) open task](inflect: true)", systemImage: "checklist")
                    Label("^[\(entry.categoryCount) category](inflect: true)", systemImage: "square.grid.2x2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if entry.pendingTasks.isEmpty {
                Text("All caught up")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.pendingTasks, id: \.widgetID) { task in
                        Button(intent: ToggleTaskDoneIntent(taskID: task.widgetID.uuidString)) {
                            HStack(spacing: 8) {
                                Image(systemName: task.isRecentlyCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundStyle(task.isRecentlyCompleted ? .green : .secondary)
                                Text(task.title)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .foregroundStyle(task.isRecentlyCompleted ? .secondary : .primary)
                                    .overlay(alignment: .center) {
                                        if task.isRecentlyCompleted {
                                            Rectangle()
                                                .fill(.secondary)
                                                .frame(height: 1)
                                        }
                                    }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
            WidgetPendingTask(widgetID: UUID(), title: "One", isRecentlyCompleted: false),
            WidgetPendingTask(widgetID: UUID(), title: "Two", isRecentlyCompleted: false),
        ],
        hasTransientCompletions: false
    )
}
