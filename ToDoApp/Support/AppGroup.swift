//
//  AppGroup.swift
//  ToDoApp
//

import Foundation

/// App Group used for SwiftData shared with the widget. Value comes from `AppGroupIdentifier` in Info.plist,
/// which is set from `APP_GROUP_IDENTIFIER` in `Configuration/Shared.xcconfig` (or `Local.xcconfig`).
enum AppGroup {
    static var identifier: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
            !value.isEmpty,
            !value.contains("$(")
        else {
            preconditionFailure(
                "Set APP_GROUP_IDENTIFIER in Configuration/Shared.xcconfig (see Configuration/Local.xcconfig.example)."
            )
        }
        return value
    }
}
