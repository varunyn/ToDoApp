import SwiftData
import SwiftUI
import WidgetKit

struct PrivateListBackupsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Category> { $0.sharedZoneName != nil }, sort: \Category.order)
    private var backups: [Category]
    @State private var selected: Category?
    @State private var saveError: String?

    var body: some View {
        List {
            Section {
                Text("These are the original private lists from when sharing began. They don’t include later shared edits.")
                    .foregroundStyle(.secondary)
            }
            if backups.isEmpty {
                ContentUnavailableView("No backups", systemImage: "tray", description: Text("Sharing a category retains its original data here."))
            }
            ForEach(backups) { category in
                Button {
                    selected = category
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name.isEmpty ? "Untitled" : category.name)
                        Text("\(category.taskItems.count) tasks · restore private list")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Private backups")
        .confirmationDialog("Restore private list?", isPresented: confirmationIsPresented, titleVisibility: .visible) {
            Button("Restore") { restore() }
        } message: {
            Text("The original list will appear in your private categories. Any current shared version stays separate.")
        }
        .alert("Couldn’t restore backup", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
    }

    private func restore() {
        guard let selected else { return }
        selected.sharedZoneName = nil
        selected.pendingShareZoneName = nil
        for item in selected.taskItems { item.widgetID = UUID() }
        do {
            try PersistenceSupport.save(context)
            self.selected = nil
            WidgetCenter.shared.reloadTimelines(ofKind: "TodoSummaryWidget")
        } catch { saveError = PersistenceSupport.userMessage(for: error) }
    }
    private var confirmationIsPresented: Binding<Bool> {
        Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })
    }
    private var errorIsPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }
}
