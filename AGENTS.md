## Learned User Preferences

- For this project, open and build using `ToDoApp.xcodeproj` instead of `ToDoApp.xcworkspace` (the workspace was for CocoaPods; the app no longer uses Pods).
- Prefers completed tasks to automatically move below unfinished tasks.
- Prefers autosave UX for profile edits instead of requiring a separate Save button.
- When requesting commits, often wants multiple focused commits grouped by change area.

## Learned Workspace Facts

- The app targets iOS 26.0 minimum with Swift 6, SwiftUI, and SwiftData; tasks and categories persist on device only.
- SwiftData models are `Category` and `Item` under `ToDoApp/DataModel/`.
- README documents local setup: open `ToDoApp.xcodeproj`, pick a run destination, and sign for a physical device when needed.
- Cursor/agent skills for Swift work live under `.agents/skills/` (including `swiftdata-pro`, `swiftui-pro`, and `swift-concurrency-pro`).
