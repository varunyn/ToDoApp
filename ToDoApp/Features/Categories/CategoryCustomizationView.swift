//
//  CategoryCustomizationView.swift
//  ToDoApp
//

import SwiftData
import SwiftUI

struct CategoryCustomizationView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var goalEnabled: Bool
    @State private var persistenceErrorMessage: String?

    init(category: Category) {
        self.category = category
        _goalEnabled = State(initialValue: category.goal != nil)
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField("Name", text: $category.name)
                    .textInputAutocapitalization(.words)
            }

            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                    ForEach(CategoryIcon.allCases) { icon in
                        Button {
                            category.icon = icon
                        } label: {
                            Image(systemName: icon.rawValue)
                                .font(.title3)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(
                                    category.icon == icon
                                        ? category.color.colors[1].opacity(0.25)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(category.color.colors[1])
                        .accessibilityLabel(Text(icon.title))
                        .accessibilityAddTraits(category.icon == icon ? .isSelected : [])
                    }
                }
            }

            Section("Color") {
                HStack {
                    ForEach(CategoryColor.allCases) { color in
                        Button {
                            category.color = color
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: color.colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if category.color == color {
                                        Circle().stroke(.primary, lineWidth: 3).padding(-4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(color.rawValue + 1)")
                        .accessibilityAddTraits(category.color == color ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section("Task sorting") {
                Picker("Sort tasks by", selection: $category.sortRule) {
                    ForEach(CategorySortRule.allCases) { rule in
                        Label(rule.title, systemImage: rule.systemImage).tag(rule)
                    }
                }
            }

            Section("Completion goal") {
                Toggle("Set a category goal", isOn: $goalEnabled)
                    .onChange(of: goalEnabled) {
                        if goalEnabled {
                            category.goal = max(category.goal ?? 1, 1)
                        } else {
                            category.goal = nil
                        }
                    }

                if goalEnabled {
                    Stepper(value: goalBinding, in: 1...10_000) {
                        LabeledContent("Tasks to complete", value: "\(category.goal ?? 1)")
                    }
                }
            }
        }
        .navigationTitle("Edit category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    save()
                }
            }
        }
        .alert("Couldn’t save changes", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Please try again.")
        }
        .onDisappear {
            do {
                try PersistenceSupport.save(modelContext)
            } catch {
                persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
            }
        }
    }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { category.goal ?? 1 },
            set: { category.goal = max($0, 1) }
        )
    }

    private func save() {
        do {
            try PersistenceSupport.save(modelContext)
            dismiss()
        } catch {
            persistenceErrorMessage = PersistenceSupport.userMessage(for: error)
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
    let category = Category(name: "Work")
    container.mainContext.insert(category)
    return NavigationStack {
        CategoryCustomizationView(category: category)
    }
    .modelContainer(container)
}
