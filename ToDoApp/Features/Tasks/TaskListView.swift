//
//  TaskListView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct TaskListView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var filter: TaskListFilter = .all
    @State private var searchText = ""
    @State private var completedFeedbackTrigger = 0
    @State private var reopenedFeedbackTrigger = 0
    @State private var editingItemID: PersistentIdentifier?
    @State private var editedTaskTitle = ""
    @State private var orderedItemsCache: [Item] = []

    private var orderedItems: [Item] {
        orderedItemsCache
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
                .padding(.horizontal, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if displayedItems.isEmpty {
                taskEmptyState
                    .listRowBackground(Color.clear)
            } else if canReorder {
                ForEach(displayedItems) { item in
                    taskRow(item)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                beginEditing(item)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
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
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                beginEditing(item)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
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
        .listStyle(.plain)
        .navigationTitle(category.name.isEmpty ? "Tasks" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks")
        .alert(
            "Edit task",
            isPresented: Binding(
                get: { editingItemID != nil },
                set: { isPresented in
                    if !isPresented {
                        editingItemID = nil
                    }
                }
            )
        ) {
            TextField("Task title", text: $editedTaskTitle)
            Button("Save", action: saveEditedTask)
            Button("Cancel", role: .cancel) {
                editingItemID = nil
            }
        } message: {
            Text("Update the task title.")
        }
        .sensoryFeedback(.success, trigger: completedFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: reopenedFeedbackTrigger)
        .onAppear(perform: reloadOrderedItems)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                reloadOrderedItems()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reloadOrderedItems()
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: item.isDone)
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                beginEditing(item)
            }
        }
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
        reloadOrderedItems()
    }

    private func deleteItem(_ item: Item) {
        modelContext.delete(item)
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        reloadOrderedItems()
    }

    private func beginEditing(_ item: Item) {
        editingItemID = item.persistentModelID
        editedTaskTitle = item.title
    }

    private func saveEditedTask() {
        guard
            let id = editingItemID,
            let item = orderedItemsCache.first(where: { $0.persistentModelID == id })
        else {
            editingItemID = nil
            return
        }

        let trimmed = editedTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingItemID = nil
            return
        }

        item.title = trimmed
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        reloadOrderedItems()
        editingItemID = nil
    }

    private func moveItemsAll(from source: IndexSet, to destination: Int) {
        var items = displayedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        reloadOrderedItems()
    }

    private func reloadOrderedItems() {
        modelContext.rollback()
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.order)])
        let fetchedItems = (try? modelContext.fetch(descriptor)) ?? []
        orderedItemsCache = fetchedItems.filter { $0.category?.persistentModelID == category.persistentModelID }
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
