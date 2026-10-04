//
//  PersistenceSupport.swift
//  ToDoApp
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum PersistenceSupport {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ToDoApp", category: "Persistence")

    static func save(_ modelContext: ModelContext) throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    static func userMessage(for _: Error) -> String {
        "Your changes couldn’t be saved. Nothing was lost from the existing list. Please try again."
    }
}
