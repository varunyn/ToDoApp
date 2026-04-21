//
//  TaskListView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

struct TaskListView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext

    @State private var segment = 0

    private var baseItems: [Item] {
        category.items.sorted { $0.order < $1.order }
    }

    private var filteredItems: [Item] {
        switch segment {
        case 1:
            return baseItems.filter(\.isDone)
        case 2:
            return baseItems.filter { !$0.isDone }
        default:
            return baseItems
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $segment) {
                    Text("All").tag(0)
                    Text("Completed").tag(1)
                    Text("Pending").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if segment == 0 {
                ForEach(filteredItems) { item in
                    taskRow(item)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItemsAll)
            } else {
                ForEach(filteredItems) { item in
                    taskRow(item)
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle(category.name.isEmpty ? "Tasks" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AddTaskView(category: category)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add task")
            }
            if segment == 0 {
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
            let item = filteredItems[index]
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
