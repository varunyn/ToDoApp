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
    @State private var renamingCategoryID: PersistentIdentifier?
    @State private var renamedCategoryName = ""
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
                    dashboardHero
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
                            ForEach(Array(filteredCategories.enumerated()), id: \.element.persistentModelID) { index, category in
                                categoryCell(category, index: index)
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
            .alert(
                "Rename category",
                isPresented: Binding(
                    get: { renamingCategoryID != nil },
                    set: { isPresented in
                        if !isPresented {
                            renamingCategoryID = nil
                        }
                    }
                )
            ) {
                TextField("Name", text: $renamedCategoryName)
                Button("Save", action: saveRenamedCategory)
                Button("Cancel", role: .cancel) {
                    renamingCategoryID = nil
                }
            } message: {
                Text("Enter a new category name.")
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

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedToday)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayNameLabel)
                .font(.title3.bold())

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .leading),
                    GridItem(.flexible(), spacing: 10, alignment: .leading),
                ],
                alignment: .leading,
                spacing: 8
            ) {
                Label("\(totalTaskCount) Tasks", systemImage: "checklist")
                Label("\(completedTaskCount) Completed", systemImage: "checkmark.circle.fill")
                Label("\(categories.count) Categories", systemImage: "square.grid.2x2.fill")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemGray6), Color(.systemGray5).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
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
    private func categoryCell(_ category: Category, index: Int) -> some View {
        let isSelected = selectedIDs.contains(category.persistentModelID)
        let progress = categoryProgress(for: category)
        Button {
            if isSelecting {
                toggleSelection(category)
            } else {
                navigationPath.append(category.persistentModelID)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(category.name.isEmpty ? "Untitled" : category.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    HStack {
                        Spacer(minLength: 0)
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.35), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "briefcase.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(width: 74, height: 74)
                        Spacer(minLength: 0)
                    }

                    HStack {
                        Label(
                            "\(categoryCompletedCount(for: category))/\(max(category.items.count, 1))",
                            systemImage: "gearshape.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("Lv.\(categoryLevel(for: category))")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: AppAppearance.cardMinHeight, alignment: .topLeading)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: AppAppearance.cardCornerRadius, style: .continuous)
                        .fill(categoryGradient(at: index))
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
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                beginRenaming(category)
            }
        }
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

    private func categoryCompletedCount(for category: Category) -> Int {
        category.items.filter(\.isDone).count
    }

    private func categoryProgress(for category: Category) -> CGFloat {
        guard !category.items.isEmpty else { return 0 }
        return CGFloat(categoryCompletedCount(for: category)) / CGFloat(category.items.count)
    }

    private func categoryLevel(for category: Category) -> Int {
        (categoryCompletedCount(for: category) / 5) + 1
    }

    private func categoryGradient(at index: Int) -> LinearGradient {
        let palette: [[Color]] = [
            [Color(red: 1.0, green: 0.74, blue: 0.68), Color(red: 0.98, green: 0.56, blue: 0.52)],
            [Color(red: 0.50, green: 0.90, blue: 1.0), Color(red: 0.23, green: 0.73, blue: 0.98)],
            [Color(red: 0.84, green: 1.0, blue: 0.53), Color(red: 0.69, green: 0.92, blue: 0.27)],
            [Color(red: 0.78, green: 0.61, blue: 1.0), Color(red: 0.60, green: 0.42, blue: 0.96)],
        ]
        let colors = palette[index % palette.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func beginRenaming(_ category: Category) {
        renamingCategoryID = category.persistentModelID
        renamedCategoryName = category.name
    }

    private func saveRenamedCategory() {
        guard
            let id = renamingCategoryID,
            let category = categories.first(where: { $0.persistentModelID == id })
        else {
            renamingCategoryID = nil
            return
        }

        let trimmed = renamedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renamingCategoryID = nil
            return
        }

        category.name = trimmed
        try? modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        renamingCategoryID = nil
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
