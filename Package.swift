// swift-tools-version: 6.2
import PackageDescription

// Runs the shared-list merge and persistence contracts without iCloud credentials.
let package = Package(
    name: "TokiSharing",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "TokiSharing", path: "ToDoApp",
                exclude: ["App", "Assets.xcassets", "Base.lproj", "Design", "Info.plist", "ToDoApp.entitlements",
                          "Features/Categories/CategoryListView.swift", "Features/Categories/CategoryReorderView.swift",
                          "Features/Categories/CategoryCustomizationView.swift", "Features/Categories/HomeHeaderView.swift",
                          "Features/Tasks/EditTaskView.swift", "Features/Tasks/QuickAddView.swift", "Features/Tasks/TaskListView.swift",
                          "Features/Tasks/TaskListFilter.swift", "Features/Sharing/CloudSharingSheet.swift",
                          "Features/Sharing/SharedListStore.swift",
                          "Features/Sharing/SharedTaskEditor.swift", "Features/Sharing/SharedTaskListView.swift",
                          "Features/Sharing/SharingAppDelegate.swift", "Features/Sharing/SharingSceneDelegate.swift",
                          "Features/Sharing/PrivateListBackupsView.swift"],
                sources: ["Features/Sharing/SharedList.swift", "Features/Sharing/SharedTask.swift",
                          "Features/Sharing/SharedListCache.swift", "Support/AppGroup.swift",
                          "DataModel/Category.swift", "DataModel/Item.swift", "Features/Categories/CategoryCustomization.swift",
                          "Features/Tasks/TaskPriority.swift"]),
        .testTarget(name: "TokiSharingTests", dependencies: ["TokiSharing"], path: "Tests/Sharing")
    ]
)
