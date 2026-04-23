//
//  TaskListView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI
import WidgetKit

struct TaskListView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var filter: TaskListFilter = .all
    @State private var searchText = ""
    @State private var completedFeedbackTrigger = 0
    @State private var reopenedFeedbackTrigger = 0
    @State private var refreshToken = UUID()

    private var orderedItems: [Item] {
        _ = refreshToken
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.order)])
        let fetchedItems = (try? modelContext.fetch(descriptor)) ?? []
        return fetchedItems.filter { $0.category?.persistentModelID == category.persistentModelID }
    }

    private var allItemsByCompletionThenOrder: [Item] {
        let pending = orderedItems.filter { !$0.isDone }
        let completed = orderedItems.filter(\.isDone)
        return pending + completed
    }

    private var itemsForSegment: [Item] {
        switch filter {
        case .all:
            return allItemsByCompletionThenOrder
        case .completed:
            return orderedItems.filter(\.isDone)
        case .pending:
            return orderedItems.filter { !$0.isDone }
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedItems: [Item] {
        guard !trimmedSearch.isEmpty else { return itemsForSegment }
        return itemsForSegment.filter { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = title.isEmpty ? "Untitled task" : title
            return label.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    private var canReorder: Bool {
        filter == .all && trimmedSearch.isEmpty
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(TaskListFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if displayedItems.isEmpty {
                taskEmptyState
                    .listRowBackground(Color.clear)
            } else if canReorder {
                ForEach(displayedItems) { item in
                    taskRow(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: moveItemsAll)
            } else {
                ForEach(displayedItems) { item in
                    taskRow(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(category.name.isEmpty ? "Tasks" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks")
        .sensoryFeedback(.success, trigger: completedFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: reopenedFeedbackTrigger)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                refreshToken = UUID()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AddTaskView(category: category)
                } label: {
                    Label("Add task", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Add task")
            }
            if canReorder {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    @ViewBuilder
    private var taskEmptyState: some View {
        if trimmedSearch.isEmpty {
            ContentUnavailableView(
                "No tasks",
                systemImage: "checklist",
                description: Text("Tap Add task in the toolbar to create one.")
            )
        } else {
            ContentUnavailableView.search(text: trimmedSearch)
        }
    }

    @ViewBuilder
    private func taskRow(_ item: Item) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                toggleDone(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isDone ? AppAppearance.accent : .primary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
                    .frame(width: AppAppearance.minimumTapTarget, height: AppAppearance.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isDone ? "Mark as not done" : "Mark as done")

            Text(item.title.isEmpty ? "Untitled task" : item.title)
                .strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .contentTransition(.interpolate)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: item.isDone)
    }

    private func toggleDone(_ item: Item) {
        let wasDone = item.isDone
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            item.isDone.toggle()
        }
        if item.isDone, !wasDone {
            completedFeedbackTrigger += 1
        } else if !item.isDone, wasDone {
            reopenedFeedbackTrigger += 1
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private func deleteItem(_ item: Item) {
        modelContext.delete(item)
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private func moveItemsAll(from source: IndexSet, to destination: Int) {
        var items = displayedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    let category = Category(name: "Work", order: 0)
    container.mainContext.insert(category)
    return NavigationStack {
        TaskListView(category: category)
    }
    .modelContainer(container)
}
