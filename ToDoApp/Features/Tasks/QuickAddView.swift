//
//  QuickAddView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI
import WidgetKit

extension Notification.Name {
    static let tasksDidChange = Notification.Name("tasksDidChange")
}

struct QuickAddView: View {
    let defaultCategory: Category?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var isExpanded = false
    @State private var title = ""
    @State private var priority: TaskPriority = .none
    @State private var selectedCategory: Category?
    @State private var persistenceErrorMessage: String?
    @FocusState private var isTitleFocused: Bool

    private var destinationCategory: Category? {
        selectedCategory ?? defaultCategory ?? categories.first
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedQuickAdd
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button(action: open) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(AppAppearance.accent, in: Circle())
                        .shadow(color: AppAppearance.accent.opacity(0.3), radius: 12, y: 6)
                }
                .accessibilityLabel("New task")
                .accessibilityHint("Opens quick add")
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .background(isExpanded ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
        .overlay(alignment: .top) {
            if isExpanded {
                Rectangle()
                    .fill(AppAppearance.taskBorder)
                    .frame(height: 1)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isExpanded)
        .alert("Couldn’t save changes", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Please try again.")
        }
    }

    private var expandedQuickAdd: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppAppearance.accent)
                    .accessibilityHidden(true)

                TextField("What needs to be done?", text: $title)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit(addTask)

                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Close quick add")
            }

            HStack(spacing: 8) {
                categoryMenu
                priorityMenu
                Spacer(minLength: 0)

                Button(action: addTask) {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(AppAppearance.accent, in: Circle())
                }
                .disabled(trimmedTitle.isEmpty || destinationCategory == nil)
                .opacity(trimmedTitle.isEmpty || destinationCategory == nil ? 0.5 : 1)
                .accessibilityLabel("Add task")
            }
        }
        .padding(14)
        .frame(maxWidth: 560)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(
                        category.name.isEmpty ? "Untitled" : category.name,
                        systemImage: category.persistentModelID == destinationCategory?.persistentModelID ? "checkmark" : category.icon.rawValue
                    )
                }
            }
        } label: {
            Label(categoryName, systemImage: destinationCategory?.icon.rawValue ?? "folder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AppAppearance.taskSurface, in: Capsule())
                .overlay { Capsule().stroke(AppAppearance.taskBorder, lineWidth: 1) }
        }
        .disabled(categories.isEmpty)
        .accessibilityLabel("Category")
        .accessibilityValue(categoryName)
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(TaskPriority.allCases) { option in
                Button {
                    priority = option
                } label: {
                    Label(option.title, systemImage: option.systemImage)
                }
            }
        } label: {
            Label(priority == .none ? "Priority" : priority.title, systemImage: priority.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(priority == .none ? .secondary : priority.tint)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(AppAppearance.taskSurface, in: Capsule())
                .overlay { Capsule().stroke(AppAppearance.taskBorder, lineWidth: 1) }
        }
        .accessibilityLabel("Priority")
        .accessibilityValue(Text(priority.title))
    }

    private var categoryName: String {
        guard let destinationCategory else { return "Category" }
        return destinationCategory.name.isEmpty ? "Untitled" : destinationCategory.name
    }

    private func open() {
        selectedCategory = defaultCategory
        withAnimation { isExpanded = true }
        Task { @MainActor in isTitleFocused = true }
    }

    private func close() {
        isTitleFocused = false
        withAnimation { isExpanded = false }
    }

    private func addTask() {
        guard !trimmedTitle.isEmpty, let destinationCategory else { return }
        let nextOrder = (destinationCategory.items.map(\.order).max() ?? -1) + 1
        let item = Item(
            title: trimmedTitle,
            isDone: false,
            order: nextOrder,
            priority: priority,
            category: destinationCategory
        )
        modelContext.insert(item)
        do {
            try PersistenceSupport.save(modelContext)
        } catch {
            persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
            return
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
        title = ""
        priority = .none
        selectedCategory = defaultCategory
        isTitleFocused = true
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { if !$0 { persistenceErrorMessage = nil } }
        )
    }
}
