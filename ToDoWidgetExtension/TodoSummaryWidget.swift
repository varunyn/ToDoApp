//
//  TodoSummaryWidget.swift
//  ToDoWidgetExtension
//

import SwiftData
import SwiftUI
import WidgetKit

struct TodoSummaryEntry: TimelineEntry {
    let date: Date
    let openTaskCount: Int
    let categoryCount: Int
    let pendingTitles: [String]
}

struct TodoSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoSummaryEntry {
        TodoSummaryEntry(
            date: .now,
            openTaskCount: 3,
            categoryCount: 2,
            pendingTitles: ["Buy milk", "Call back", "Review notes"]
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
            return TodoSummaryEntry(date: .now, openTaskCount: 0, categoryCount: 0, pendingTitles: [])
        }
        let context = ModelContext(container)
        let openItems = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { !$0.isDone }))) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let sorted = openItems.sorted { $0.order < $1.order }
        let titles = sorted.prefix(5).map { item in
            let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Untitled task" : t
        }
        return TodoSummaryEntry(
            date: .now,
            openTaskCount: openItems.count,
            categoryCount: categories.count,
            pendingTitles: Array(titles)
        )
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
                if entry.pendingTitles.isEmpty {
                    Text("All caught up")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(entry.pendingTitles.enumerated()), id: \.offset) { _, title in
                        Text(title)
                            .font(.caption)
                            .lineLimit(1)
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
    TodoSummaryEntry(date: .now, openTaskCount: 4, categoryCount: 2, pendingTitles: ["One", "Two"])
}
