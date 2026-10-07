//
//  TaskListView.swift
//  ToDoApp
//

import CloudKit
import SwiftData
import SwiftUI
import WidgetKit

struct TaskListView: View {
    @Environment(SharedListStore.self) private var sharing
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filter: TaskListFilter = .all
    @State private var searchText = ""
    @State private var completedFeedbackTrigger = 0
    @State private var reopenedFeedbackTrigger = 0
    @State private var editingItem: Item?
    @State private var persistenceErrorMessage: String?
    @State private var cloudShare: CKShare?
    @State private var showingCloudShare = false
    @State private var isPreparingShare = false
    @State private var sharingErrorMessage: String?

    var body: some View {
        Group {
            if let zone = category.sharedZoneName,
               let list = sharing.lists.first(where: { $0.isOwner && $0.zoneName == zone }) {
                SharedTaskListView(listID: list.id)
                    .sheet(isPresented: $showingCloudShare) {
                        if let cloudShare {
                            CloudSharingSheet(share: cloudShare, container: sharing.container, title: list.name,
                                              onChange: { sharing.requestSync() }, onError: sharing.report)
                        }
                    }
            } else {
                privateListBody
            }
        }
        .alert("Couldn’t share list", isPresented: sharingErrorIsPresented) {
            Button("OK", role: .cancel) { sharingErrorMessage = nil }
        } message: { Text(sharingErrorMessage ?? "Please try again.") }
    }

    private var orderedItems: [Item] {
        category.taskItems.sorted { lhs, rhs in
            if lhs.isDone != rhs.isDone {
                return !lhs.isDone
            }

            switch category.sortRule {
            case .manual, .completion:
                return lhs.order < rhs.order
            case .priority:
                if lhs.priorityRawValue != rhs.priorityRawValue {
                    return lhs.priorityRawValue > rhs.priorityRawValue
                }
                return lhs.order < rhs.order
            case .name:
                let leftTitle = lhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let rightTitle = rhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let comparison = leftTitle.localizedCaseInsensitiveCompare(rightTitle)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return lhs.order < rhs.order
            }
        }
    }

    private var itemsForSegment: [Item] {
        switch filter {
        case .all:
            return orderedItems
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
        filter == .all && trimmedSearch.isEmpty && category.sortRule == .manual
    }

    private var privateListBody: some View {
        List {
            Section {
                filterControl
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)

                todayHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
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
        .scrollContentBackground(.hidden)
        .background(AppAppearance.taskBackground)
        .navigationTitle(category.name.isEmpty ? "Tasks" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddView(defaultCategory: category)
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                EditTaskView(item: item)
            }
        }
        .sensoryFeedback(.success, trigger: completedFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: reopenedFeedbackTrigger)
        .alert("Couldn’t save changes", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Please try again.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(isPreparingShare ? "Preparing…" : "Share List", systemImage: "person.badge.plus") {
                    publishAndShare()
                }
                .disabled(isPreparingShare || sharing.isSyncing)
                if canReorder {
                    EditButton()
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .disabled(isPreparingShare)
    }

    private func publishAndShare() {
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do {
                let list = try await sharing.publish(category, context: modelContext)
                category.sharedZoneName = list.zoneName
                try PersistenceSupport.save(modelContext)
                cloudShare = try await sharing.share(for: list.id)
                showingCloudShare = true
            } catch {
                sharing.report(error)
                sharingErrorMessage = sharing.errorMessage
            }
        }
    }

    private var sharingErrorIsPresented: Binding<Bool> {
        Binding(get: { sharingErrorMessage != nil }, set: { if !$0 { sharingErrorMessage = nil } })
    }

    private var filterControl: some View {
        HStack(spacing: 4) {
            ForEach(TaskListFilter.allCases) { option in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        filter = option
                    }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(filter == option ? .semibold : .regular))
                        .foregroundStyle(filter == option ? AppAppearance.accent : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if filter == option {
                                Capsule(style: .continuous)
                                    .fill(AppAppearance.accent.opacity(0.13))
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(AppAppearance.accent.opacity(0.18), lineWidth: 1)
                                    }
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppAppearance.taskBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Task filter")
    }

    private var todayHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tasks")
                    .font(.title2.weight(.bold))
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text("\(displayedItems.count) \(displayedItems.count == 1 ? "task" : "tasks")")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title.isEmpty ? "Untitled task" : item.title)
                    .font(.body.weight(.medium))
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .contentTransition(.interpolate)

                if item.priority != .none {
                    Label(item.priority.title, systemImage: item.priority.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(item.priority.tint)
                        .accessibilityLabel("\(item.priority.title) priority")
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                if !item.isDone {
                    Text(item.pendingAgeLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(
                            item.pendingAgeLabel == "Today"
                                ? "Pending since today"
                                : "Pending for \(item.pendingAgeLabel)"
                        )
                }

                Button {
                    toggleDone(item)
                } label: {
                    ZStack {
                        Circle()
                            .fill(item.isDone ? AppAppearance.accent.opacity(0.16) : .clear)
                        Circle()
                            .stroke(
                                item.isDone ? AppAppearance.accent : AppAppearance.accent.opacity(0.48),
                                lineWidth: 1.5
                        )
                        if item.isDone {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppAppearance.accent)
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        }
                    }
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
                    .symbolEffectsRemoved(reduceMotion)
                    .frame(width: 26, height: 26)
                    .frame(width: AppAppearance.minimumTapTarget, height: AppAppearance.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isDone ? "Mark as not done" : "Mark as done")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppAppearance.taskSurface)
                .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .opacity(item.isDone ? 0.58 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78), value: item.isDone)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                beginEditing(item)
            }
        }
    }

    private func toggleDone(_ item: Item) {
        let wasDone = item.isDone
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72)) {
            item.isDone.toggle()
        }
        if item.isDone, !wasDone {
            completedFeedbackTrigger += 1
        } else if !item.isDone, wasDone {
            reopenedFeedbackTrigger += 1
        }
        saveChanges()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private func deleteItem(_ item: Item) {
        modelContext.delete(item)
        saveChanges()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private func beginEditing(_ item: Item) {
        editingItem = item
    }

    private func moveItemsAll(from source: IndexSet, to destination: Int) {
        var items = displayedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
        saveChanges()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { if !$0 { persistenceErrorMessage = nil } }
        )
    }

    private func saveChanges() {
        do {
            try PersistenceSupport.save(modelContext)
        } catch {
            persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
        }
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
    .environment(SharedListStore.shared)
}
