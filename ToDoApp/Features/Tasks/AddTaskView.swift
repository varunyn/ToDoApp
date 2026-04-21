//
//  AddTaskView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

struct AddTaskView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Task title", text: $title)
                    .focused($isFieldFocused)
            }
        }
        .navigationTitle("New task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addTask()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            isFieldFocused = true
        }
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (category.items.map(\.order).max() ?? -1) + 1
        let item = Item(title: trimmed, isDone: false, order: nextOrder, category: category)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    let category = Category(name: "Preview", order: 0)
    container.mainContext.insert(category)
    return NavigationStack {
        AddTaskView(category: category)
    }
    .modelContainer(container)
}
