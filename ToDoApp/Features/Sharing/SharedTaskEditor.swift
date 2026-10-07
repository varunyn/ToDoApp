import SwiftUI

struct SharedTaskEditor: View {
    let task: SharedTask
    let save: (String, Int) -> Bool
    @Environment(SharedListStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var priority: TaskPriority

    init(task: SharedTask, save: @escaping (String, Int) -> Bool) {
        self.task = task
        self.save = save
        _title = State(initialValue: task.title)
        _priority = State(initialValue: TaskPriority(rawValue: task.priority) ?? .none)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task", text: $title)
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                }
                if let message = store.errorMessage {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit shared task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if save(title.trimmingCharacters(in: .whitespacesAndNewlines), priority.rawValue) { dismiss() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
