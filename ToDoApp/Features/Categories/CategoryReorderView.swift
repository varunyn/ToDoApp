//
//  CategoryReorderView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

struct CategoryReorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var ordered: [Category] = []

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
                        persistOrder()
                        dismiss()
                    }
                }
            }
            .onAppear {
                ordered = categories
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        ordered.move(fromOffsets: source, toOffset: destination)
    }

    private func persistOrder() {
        for (index, category) in ordered.enumerated() {
            category.order = index
        }
        try? modelContext.save()
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, Item.self, configurations: configuration)
    return CategoryReorderView()
        .modelContainer(container)
}
