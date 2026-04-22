//
//  TaskListView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

struct TaskListView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext

    @State private var filter: TaskListFilter = .all
    @State private var searchText = ""

    private var baseItems: [Item] {
        category.items.sorted { $0.order < $1.order }
    }

    private var itemsForSegment: [Item] {
        switch filter {
        case .all:
            return baseItems
        case .completed:
            return baseItems.filter(\.isDone)
        case .pending:
            return baseItems.filter { !$0.isDone }
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

            if canReorder {
                ForEach(displayedItems) { item in
                    taskRow(item)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItemsAll)
            } else {
                ForEach(displayedItems) { item in
                    taskRow(item)
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle(category.name.isEmpty ? "Tasks" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AddTaskView(category: category)
                } label: {
                    Label("Add task", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
            }
            if canReorder {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
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
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .frame(width: AppAppearance.minimumTapTarget, height: AppAppearance.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isDone ? "Mark as not done" : "Mark as done")

            Text(item.title.isEmpty ? "Untitled task" : item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)
        }
    }

    private func toggleDone(_ item: Item) {
        item.isDone.toggle()
        try? modelContext.save()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = displayedItems[index]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func moveItemsAll(from source: IndexSet, to destination: Int) {
        var items = baseItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
        try? modelContext.save()
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
