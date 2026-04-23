//
//  CategoryListView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI
import WidgetKit

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @AppStorage("Key") private var storedDisplayName = ""

    @State private var isSelecting = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showReorder = false
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: AppAppearance.gridSpacing),
        GridItem(.flexible(), spacing: AppAppearance.gridSpacing),
    ]

    private var totalTaskCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    private var completedTaskCount: Int {
        categories.reduce(0) { partial, category in
            partial + category.items.filter(\.isDone).count
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredCategories: [Category] {
        guard !trimmedSearch.isEmpty else { return categories }
        return categories.filter { category in
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = name.isEmpty ? "Untitled" : name
            return label.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if categories.isEmpty {
                        ContentUnavailableView(
                            "No categories",
                            systemImage: "square.grid.2x2",
                            description: Text("Tap Add category in the toolbar to create one.")
                        )
                        .padding(.top, 40)
                    } else if !trimmedSearch.isEmpty, filteredCategories.isEmpty {
                        ContentUnavailableView.search(text: trimmedSearch)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: AppAppearance.gridSpacing) {
                            ForEach(filteredCategories) { category in
                                categoryCell(category)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(for: PersistentIdentifier.self, destination: destinationView)
            .navigationTitle(isSelecting ? "Select Items" : "Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("Cancel", role: .cancel, action: cancelSelection)
                    } else {
                        Button("Select") {
                            isSelecting = true
                        }
                    }
                    Button("Reorder", systemImage: "arrow.up.arrow.down") {
                        showReorder = true
                    }
                    .disabled(categories.count < 2 || isSelecting)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add category", systemImage: "plus") {
                        newCategoryName = ""
                        showAddCategory = true
                    }
                    .disabled(isSelecting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    selectionFooter
                }
            }
            .sheet(isPresented: $showReorder) {
                CategoryReorderView()
            }
            .alert("Category", isPresented: $showAddCategory) {
                TextField("Name", text: $newCategoryName)
                Button("Add", action: addCategory)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new category.")
            }
            .searchable(text: $searchText, prompt: "Search categories")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formattedToday)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(displayNameLabel)
                    .font(.title2)
                    .bold()
                Spacer()
            }
            HStack(spacing: 24) {
                Label {
                    Text("^[\(totalTaskCount) task](inflect: true)")
                } icon: {
                    Image(systemName: "list.bullet")
                }
                Label {
                    Text(verbatim: "\(completedTaskCount) completed")
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var formattedToday: String {
        Date.now.formatted(
            .dateTime
                .weekday(.wide)
                .month(.abbreviated)
                .day()
        )
    }

    private var displayNameLabel: String {
        let trimmed = storedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your list" : trimmed
    }

    @ViewBuilder
    private func destinationView(for id: PersistentIdentifier) -> some View {
        if let category = category(for: id) {
            TaskListView(category: category)
        }
    }

    private func category(for id: PersistentIdentifier) -> Category? {
        categories.first { $0.persistentModelID == id }
    }

    @ViewBuilder
    private func categoryCell(_ category: Category) -> some View {
        let isSelected = selectedIDs.contains(category.persistentModelID)
        Button {
            if isSelecting {
                toggleSelection(category)
            } else {
                navigationPath.append(category.persistentModelID)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.name.isEmpty ? "Untitled" : category.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text("^[\(category.items.count) task](inflect: true)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: AppAppearance.cardMinHeight, alignment: .topLeading)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: AppAppearance.cardCornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .strokeBorder(AppAppearance.accent.opacity(0.25), lineWidth: 1)
                }

                if isSelecting, isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppAppearance.accent)
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name.isEmpty ? "Untitled category" : category.name)
        .accessibilityHint(isSelecting ? "Toggles selection for delete" : "Opens tasks for this category")
    }

    private var selectionFooter: some View {
        HStack {
            Spacer()
            Button(role: .destructive, action: deleteSelectedCategories) {
                Label("Delete selected", systemImage: "trash.fill")
            }
            .disabled(selectedIDs.isEmpty)
            .frame(minWidth: AppAppearance.minimumTapTarget, minHeight: AppAppearance.minimumTapTarget)
            Spacer()
        }
        .padding(.vertical, 12)
        .background(AppAppearance.accent.opacity(0.12))
    }

    private func toggleSelection(_ category: Category) {
        let id = category.persistentModelID
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func cancelSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (categories.map(\.order).max() ?? -1) + 1
        let category = Category(name: trimmed, order: nextOrder)
        modelContext.insert(category)
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
    }

    private func deleteSelectedCategories() {
        let toDelete = categories.filter { selectedIDs.contains($0.persistentModelID) }
        for category in toDelete {
            modelContext.delete(category)
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        cancelSelection()
    }
}

private struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]

    @AppStorage("Key") private var storedDisplayName = ""
    @State private var showClearDataConfirmation = false
    @State private var isClearingData = false

    private var totalTaskCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    private var completedTaskCount: Int {
        categories.reduce(0) { partial, category in
            partial + category.items.filter(\.isDone).count
        }
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $storedDisplayName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }

            Section("Stats") {
                LabeledContent("Categories", value: "\(categories.count)")
                LabeledContent("Tasks", value: "\(totalTaskCount)")
                LabeledContent("Completed", value: "\(completedTaskCount)")
            }

            Section("Danger Zone") {
                Button("Clear all data", role: .destructive) {
                    showClearDataConfirmation = true
                }
                .disabled(isClearingData)
                .accessibilityHint("Deletes all categories and tasks")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Clear all app data?",
            isPresented: $showClearDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear all data", role: .destructive, action: clearAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all categories and tasks.")
        }
        .onDisappear(perform: normalizeDisplayName)
    }

    private func clearAllData() {
        guard !isClearingData else { return }
        isClearingData = true

        for category in categories {
            modelContext.delete(category)
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        isClearingData = false
        dismiss()
    }

    private func normalizeDisplayName() {
        storedDisplayName = storedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    return CategoryListView()
        .modelContainer(container)
}
