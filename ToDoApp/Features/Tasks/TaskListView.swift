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
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var filter: TaskListFilter = .all
    @State private var searchText = ""
    @State private var completedFeedbackTrigger = 0
    @State private var reopenedFeedbackTrigger = 0
    @State private var editingItem: Item?
    @State private var orderedItemsCache: [Item] = []
    @State private var isQuickAddExpanded = false
    @State private var quickAddTitle = ""
    @State private var quickAddPriority: TaskPriority = .none
    @State private var quickAddCategory: Category?
    @FocusState private var isQuickAddFocused: Bool
    @State private var persistenceErrorMessage: String?

    private var orderedItems: [Item] {
        orderedItemsCache.sorted { lhs, rhs in
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

    var body: some View {
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
        .onAppear(perform: reloadOrderedItems)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                reloadOrderedItems()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reloadOrderedItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasksDidChange)) { _ in
            reloadOrderedItems()
        }
        .alert("Couldn’t save changes", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Please try again.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canReorder {
                    EditButton()
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var quickAddBar: some View {
        VStack(spacing: 0) {
            if isQuickAddExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                            .foregroundStyle(AppAppearance.accent)
                            .accessibilityHidden(true)

                        TextField("What needs to be done?", text: $quickAddTitle)
                            .focused($isQuickAddFocused)
                            .submitLabel(.done)
                            .onSubmit(addQuickTask)

                        Button("Close", systemImage: "xmark") {
                            closeQuickAdd()
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Close quick add")
                    }

                    HStack(spacing: 8) {
                        categoryMenu
                        priorityMenu

                        Spacer(minLength: 0)

                        Button(action: addQuickTask) {
                            Label("Add task", systemImage: "arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(AppAppearance.accent, in: Capsule())
                        }
                        .disabled(trimmedQuickAddTitle.isEmpty)
                        .opacity(trimmedQuickAddTitle.isEmpty ? 0.5 : 1)
                    }
                }
                .padding(14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    openQuickAdd()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "plus")
                            .font(.body.weight(.bold))
                        Text("New task")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.forward")
                            .font(.caption.weight(.bold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 13)
                    .background(AppAppearance.accent, in: Capsule())
                }
                .accessibilityLabel("New task")
                .accessibilityHint("Opens quick add")
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 560)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppAppearance.taskBorder)
                .frame(height: 1)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isQuickAddExpanded)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(categories) { option in
                Button {
                    quickAddCategory = option
                } label: {
                    Label(
                        option.name.isEmpty ? "Untitled" : option.name,
                        systemImage: option.persistentModelID == selectedQuickAddCategory.persistentModelID ? "checkmark" : option.icon.rawValue
                    )
                }
            }
        } label: {
            Label(selectedQuickAddCategory.name.isEmpty ? "Untitled" : selectedQuickAddCategory.name, systemImage: selectedQuickAddCategory.icon.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AppAppearance.taskSurface, in: Capsule())
                .overlay {
                    Capsule().stroke(AppAppearance.taskBorder, lineWidth: 1)
                }
        }
        .accessibilityLabel("Category")
        .accessibilityValue(selectedQuickAddCategory.name.isEmpty ? "Untitled" : selectedQuickAddCategory.name)
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(TaskPriority.allCases) { option in
                Button {
                    quickAddPriority = option
                } label: {
                    Label(option.title, systemImage: option.systemImage)
                }
            }
        } label: {
            Label(quickAddPriority == .none ? "Priority" : quickAddPriority.title, systemImage: quickAddPriority.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(quickAddPriority == .none ? .secondary : quickAddPriority.tint)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AppAppearance.taskSurface, in: Capsule())
                .overlay {
                    Capsule().stroke(AppAppearance.taskBorder, lineWidth: 1)
                }
        }
        .accessibilityLabel("Priority")
        .accessibilityValue(Text(quickAddPriority.title))
    }

    private var trimmedQuickAddTitle: String {
        quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedQuickAddCategory: Category {
        quickAddCategory ?? category
    }

    private func openQuickAdd() {
        quickAddCategory = category
        withAnimation {
            isQuickAddExpanded = true
        }
        Task { @MainActor in
            isQuickAddFocused = true
        }
    }

    private func closeQuickAdd() {
        isQuickAddFocused = false
        withAnimation {
            isQuickAddExpanded = false
        }
    }

    private func addQuickTask() {
        guard !trimmedQuickAddTitle.isEmpty else { return }
        let destination = selectedQuickAddCategory
        let nextOrder = (destination.items.map(\.order).max() ?? -1) + 1
        let item = Item(
            title: trimmedQuickAddTitle,
            isDone: false,
            order: nextOrder,
            priority: quickAddPriority,
            category: destination
        )
        modelContext.insert(item)
        saveChanges()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        quickAddTitle = ""
        quickAddPriority = .none
        quickAddCategory = category
        reloadOrderedItems()
        isQuickAddFocused = true
    }

    private var filterControl: some View {
        HStack(spacing: 4) {
            ForEach(TaskListFilter.allCases) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
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
        HStack(spacing: 12) {
            Image(systemName: "sun.max")
                .font(.body.weight(.medium))
                .foregroundStyle(AppAppearance.accent)
                .frame(width: 38, height: 38)
                .background(AppAppearance.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.title3.weight(.semibold))
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text("\(displayedItems.count) \(displayedItems.count == 1 ? "task" : "tasks")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppAppearance.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppAppearance.accent.opacity(0.10), in: Capsule())
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
        HStack(alignment: .center, spacing: 12) {
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
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: item.isDone)
                .frame(width: 26, height: 26)
                .frame(width: AppAppearance.minimumTapTarget, height: AppAppearance.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isDone ? "Mark as not done" : "Mark as done")

            Text(item.title.isEmpty ? "Untitled task" : item.title)
                .font(.body.weight(.medium))
                .strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .contentTransition(.interpolate)

            if item.priority != .none {
                Spacer(minLength: 4)

                Label(item.priority.title, systemImage: item.priority.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(item.priority.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(item.priority.tint.opacity(0.12), in: Capsule())
                    .accessibilityLabel("\(item.priority.title) priority")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppAppearance.taskSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppAppearance.taskBorder, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.045), radius: 10, y: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .opacity(item.isDone ? 0.58 : 1)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: item.isDone)
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
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            item.isDone.toggle()
        }
        if item.isDone, !wasDone {
            completedFeedbackTrigger += 1
        } else if !item.isDone, wasDone {
            reopenedFeedbackTrigger += 1
        }
        saveChanges()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        reloadOrderedItems()
    }

    private func deleteItem(_ item: Item) {
        modelContext.delete(item)
        saveChanges()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        reloadOrderedItems()
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
        reloadOrderedItems()
    }

    private func reloadOrderedItems() {
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.order)])
        let fetchedItems = (try? modelContext.fetch(descriptor)) ?? []
        orderedItemsCache = fetchedItems.filter { $0.category?.persistentModelID == category.persistentModelID }
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
}
