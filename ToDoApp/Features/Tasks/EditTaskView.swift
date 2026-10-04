//
//  EditTaskView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI
import WidgetKit

struct EditTaskView: View {
    @Bindable var item: Item
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var persistenceErrorMessage: String?
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                editorHeader
                titleCard
                statusCard
                priorityCard
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppAppearance.taskBackground)
        .navigationTitle("Edit task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: save)
                    .font(.subheadline.weight(.semibold))
                    .disabled(trimmedTitle.isEmpty)
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete task", role: .destructive, action: deleteTask)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This task will be removed from your list.")
        }
        .alert("Couldn’t save changes", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Please try again.")
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppAppearance.accent.opacity(0.14))
                Image(systemName: item.isDone ? "checkmark" : "pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppAppearance.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.isDone ? "Completed task" : "Shape your next step")
                    .font(.title3.weight(.semibold))
                Text(categoryLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Task")

            TextField("What needs to be done?", text: $item.title, axis: .vertical)
                .focused($isTitleFocused)
                .font(.title3.weight(.medium))
                .lineLimit(2...5)
                .padding(16)
                .background(AppAppearance.taskSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isTitleFocused ? AppAppearance.accent.opacity(0.65) : AppAppearance.taskBorder, lineWidth: 1)
                }
        }
        .cardSurface()
    }

    private var statusCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                item.isDone.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? AppAppearance.accent : .secondary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.isDone ? "Task completed" : "Mark as complete")
                        .font(.body.weight(.semibold))
                    Text(item.isDone ? "Nice work — this one is done." : "Move it below unfinished tasks when finished.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
        .accessibilityLabel(item.isDone ? "Mark task as not completed" : "Mark task as completed")
        .sensoryFeedback(.selection, trigger: item.isDone)
    }

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionLabel("Priority")
                Spacer()
                Label(item.priority.title, systemImage: item.priority.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.priority.tint)
            }

            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases) { option in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            item.priority = option
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: option.systemImage)
                                .font(.body.weight(.semibold))
                            Text(option.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(item.priority == option ? option.tint : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(item.priority == option ? option.tint.opacity(0.13) : AppAppearance.taskSurface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(item.priority == option ? option.tint.opacity(0.38) : AppAppearance.taskBorder, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(item.priority == option ? .isSelected : [])
                }
            }
        }
        .cardSurface()
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete task", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 4)
    }

    private var trimmedTitle: String {
        item.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoryLabel: String {
        guard let category = item.category else { return "Personal workspace" }
        return category.name.isEmpty ? "Untitled category" : category.name
    }

    private func sectionLabel(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.7)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        item.title = trimmedTitle
        do {
            try PersistenceSupport.save(modelContext)
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
            NotificationCenter.default.post(name: .tasksDidChange, object: nil)
            dismiss()
        } catch {
            persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
        }
    }

    private func deleteTask() {
        modelContext.delete(item)
        do {
            try PersistenceSupport.save(modelContext)
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
            NotificationCenter.default.post(name: .tasksDidChange, object: nil)
            dismiss()
        } catch {
            persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { if !$0 { persistenceErrorMessage = nil } }
        )
    }
}

private extension View {
    func cardSurface() -> some View {
        padding(16)
            .background(AppAppearance.taskSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppAppearance.taskBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 12, y: 5)
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    let category = Category(name: "Work", order: 0)
    let item = Item(title: "Review notes", priority: .high, category: category)
    container.mainContext.insert(category)
    container.mainContext.insert(item)
    return NavigationStack {
        EditTaskView(item: item)
    }
    .modelContainer(container)
}
