//
//  ToDoAppApp.swift
//  ToDoApp
//

import CloudKit
import OSLog
import SwiftData
import SwiftUI

@main
struct ToDoAppApp: App {
    @UIApplicationDelegateAdaptor(SharingAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var sharing = SharedListStore.shared
    @State private var modelContainer: ModelContainer?

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ToDoApp", category: "StorageStartup")

    init() {
        _modelContainer = State(initialValue: Self.openExistingStore())
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                CategoryListView()
                    .tint(AppAppearance.accent)
                    .environment(sharing)
                    .disabled(sharing.isPublishing)
                    .task(id: scenePhase) {
                        guard scenePhase == .active else { return }
                        while !Task.isCancelled {
                            await sharing.refresh()
                            do { try await Task.sleep(for: .seconds(30)) } catch { break }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
                        sharing.accountChanged()
                    }
                    .modelContainer(modelContainer)
            } else {
                storageRecoveryView
            }
        }
    }

    private var storageRecoveryView: some View {
        ContentUnavailableView {
            Label("Your lists couldn’t be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Your saved data hasn’t been replaced. Try again to reopen your lists. If the problem continues, restart the app or contact support.")
        } actions: {
            Button("Try again") {
                modelContainer = Self.openExistingStore()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private static func openExistingStore() -> ModelContainer? {
        do {
            return try SharedModelContainer.make()
        } catch {
            logger.error("Shared store initialization failed: \(error.localizedDescription, privacy: .public)")
        }
        // Retry the same named app-group store without CloudKit. Never silently
        // switch to another database: the app and widget must share store identity.
        do {
            return try SharedModelContainer.makeSharedWithoutCloudKit()
        } catch {
            logger.error("Shared store recovery failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
