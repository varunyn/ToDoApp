import CloudKit
import SwiftUI

struct SharedTaskListView: View {
    let listID: String
    @Environment(SharedListStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var priority: TaskPriority = .none
    @State private var searchText = ""
    @State private var filter: TaskListFilter = .all
    @State private var editingTask: SharedTask?
    @State private var share: CKShare?
    @State private var isShowingShare = false
    @State private var isPreparingShare = false
    @State private var showRemovalConfirmation = false
    @State private var actionError: String?

    private var list: SharedList? { store.list(listID) }
    private var isAwaitingVerification: Bool { store.isAwaitingAccessVerification(for: listID) }
    private var canEdit: Bool { store.canEditList(listID) }
    private var displayedTasks: [SharedTask] {
        (list?.visibleTasks ?? []).filter { task in
            let matchesFilter = filter == .all || (filter == .completed ? task.isDone : !task.isDone)
            return matchesFilter && (searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List {
            Section {
                Label(status, systemImage: list?.isAvailable == false ? "icloud.slash" : "person.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let message = store.errorMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Picker("Tasks", selection: $filter) {
                    ForEach(TaskListFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            if displayedTasks.isEmpty {
                ContentUnavailableView("No tasks", systemImage: "checklist",
                    description: Text(canEdit ? "Add a task below." : "Tasks will appear here when the list syncs."))
            }
            ForEach(displayedTasks) { task in
                HStack(spacing: 12) {
                    Button {
                        store.editTask(listID: listID, taskID: task.id, isDone: !task.isDone)
                    } label: {
                        Label(task.isDone ? "Mark as unfinished" : "Complete task",
                              systemImage: task.isDone ? "checkmark.circle.fill" : "circle")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canEdit)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title).strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                        if let priority = TaskPriority(rawValue: task.priority), priority != .none {
                            Label(priority.title, systemImage: priority.systemImage)
                                .font(.caption).foregroundStyle(priority.tint)
                        }
                    }
                    Spacer()
                }
                .swipeActions(edge: .leading) {
                    if canEdit {
                        Button("Edit", systemImage: "pencil") { editingTask = task }.tint(.blue)
                    }
                }
                .swipeActions {
                    if canEdit {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.editTask(listID: listID, taskID: task.id, delete: true)
                        }
                    }
                }
                .contextMenu {
                    if canEdit { Button("Edit", systemImage: "pencil") { editingTask = task } }
                }
            }
        }
        .navigationTitle(list?.name ?? "Shared list")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks")
        .refreshable { await store.refresh() }
        .safeAreaInset(edge: .bottom) {
            if canEdit { addTaskBar }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Manage sharing", systemImage: "person.2") { prepareShare() }
                        .disabled(isPreparingShare || isAwaitingVerification || list?.isAvailable != true)
                    Button("Refresh", systemImage: "arrow.clockwise") { store.requestSync() }
                    Button(removalTitle, systemImage: "trash", role: .destructive) { showRemovalConfirmation = true }
                        .disabled(store.isSyncing || isAwaitingVerification)
                } label: { Label("List options", systemImage: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $isShowingShare) {
            if let share {
                CloudSharingSheet(share: share, container: store.container, title: list?.name ?? "Shared list",
                                  onChange: { store.requestSync() }, onError: showError)
            }
        }
        .sheet(item: $editingTask) { task in
            SharedTaskEditor(task: task) { title, priority in
                store.editTask(listID: listID, taskID: task.id,
                               title: title == task.title ? nil : title,
                               priority: priority == task.priority ? nil : priority)
            }
        }
        .confirmationDialog(removalTitle + "?", isPresented: $showRemovalConfirmation, titleVisibility: .visible) {
            Button(removalTitle, role: .destructive) {
                Task {
                    do { try await store.removeList(listID); dismiss() } catch { showError(error) }
                }
            }
        } message: {
            Text(list?.isAvailable == false ? "This removes the saved copy from this device." :
                 list?.isOwner == true ? "This deletes the shared list for everyone. Your original private backup is retained." :
                    "You’ll lose access to this list. It will remain available to everyone else.")
        }
        .alert("Sharing", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: { Text(actionError ?? "Please try again.") }
    }

    private var status: String {
        if isAwaitingVerification { return "Saved copy · waiting to verify access" }
        if list?.isAvailable == false { return "Access ended · saved copy" }
        if store.isSyncing { return "Syncing with iCloud…" }
        if list?.hasPendingChanges == true { return "Changes saved · waiting to sync" }
        if !canEdit { return "Shared list · view only" }
        return list?.isOwner == true ? "Owned by you · iCloud" : "Shared with you · can edit"
    }

    private var removalTitle: String {
        list?.isAvailable == false ? "Remove saved copy" : list?.isOwner == true ? "Delete shared list" : "Leave shared list"
    }

    private var addTaskBar: some View {
        VStack(spacing: 10) {
            TextField("What needs to be done?", text: $title).submitLabel(.done).onSubmit(addTask)
            HStack {
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                }
                Spacer()
                Button("Add task", systemImage: "plus", action: addTask)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding().background(.regularMaterial)
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if store.addTask(to: listID, title: trimmed, priority: priority.rawValue) {
            title = ""
            priority = .none
        }
    }

    private func prepareShare() {
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do { share = try await store.share(for: listID); isShowingShare = true } catch { showError(error) }
        }
    }

    private func showError(_ error: Error) { store.report(error); actionError = store.errorMessage }
    private var errorIsPresented: Binding<Bool> {
        Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
    }
}
