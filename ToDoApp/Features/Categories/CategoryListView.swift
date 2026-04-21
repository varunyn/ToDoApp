//
//  CategoryListView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

private enum UserNameStorage {
    static let key = "Key"

    static var name: String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func setName(_ name: String) {
        UserDefaults.standard.set(name, forKey: key)
    }
}

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var isSelecting = false
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showEditName = false
    @State private var editedUserName = ""
    @State private var showReorder = false
    @State private var navigationPath = NavigationPath()

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
                    } else {
                        LazyVGrid(columns: columns, spacing: AppAppearance.gridSpacing) {
                            ForEach(categories) { category in
                                categoryCell(category)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let category = categories.first(where: { $0.persistentModelID == id }) {
                    TaskListView(category: category)
                }
            }
            .navigationTitle(isSelecting ? "Select Items" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit name", systemImage: "person.crop.circle") {
                        editedUserName = UserNameStorage.name ?? ""
                        showEditName = true
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
            .alert("Your name", isPresented: $showEditName) {
                TextField("Name", text: $editedUserName)
                Button("Save") {
                    UserNameStorage.setName(editedUserName)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This name appears on the home screen.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formattedToday)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(UserNameStorage.name ?? "Your list")
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
        let today = Date.now
        let weekday = Calendar.current.component(.weekday, from: today)
        let month = Calendar.current.component(.month, from: today)
        let day = Calendar.current.component(.day, from: today)
        let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
        let monthSymbol = Calendar.current.shortMonthSymbols[month - 1]
        return "\(weekdayName), \(monthSymbol) \(day)"
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
                    Image("select")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
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
    }

    private func deleteSelectedCategories() {
        let toDelete = categories.filter { selectedIDs.contains($0.persistentModelID) }
        for category in toDelete {
            modelContext.delete(category)
        }
        try? modelContext.save()
        cancelSelection()
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    return CategoryListView()
        .modelContainer(container)
}
