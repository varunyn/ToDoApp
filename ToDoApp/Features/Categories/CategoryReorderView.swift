//
//  CategoryReorderView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

struct CategoryReorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.sharedZoneName == nil }, sort: \Category.order) private var categories: [Category]

    @State private var ordered: [Category] = []
    @State private var persistenceErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(ordered) { category in
                    Text(category.name.isEmpty ? "Untitled" : category.name)
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if persistOrder() {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Couldn’t save changes", isPresented: saveErrorIsPresented) {
                Button("OK", role: .cancel) { persistenceErrorMessage = nil }
            } message: {
                Text(persistenceErrorMessage ?? "Please try again.")
            }
            .onAppear {
                ordered = categories
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        ordered.move(fromOffsets: source, toOffset: destination)
    }

    private func persistOrder() -> Bool {
        for (index, category) in ordered.enumerated() {
            category.order = index
        }
        do {
            try PersistenceSupport.save(modelContext)
            return true
        } catch {
            persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
            return false
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { if !$0 { persistenceErrorMessage = nil } }
        )
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    return CategoryReorderView()
        .modelContainer(container)
}
