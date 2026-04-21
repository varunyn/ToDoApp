# ToDoApp

Native iOS app for organizing tasks: create **categories**, add **tasks** within each category, mark work complete, filter by status, and reorder lists.

**Stack:** Swift 6 · SwiftUI · SwiftData · Xcode

---

## Requirements

| | |
|---|---|
| **Xcode** | A recent release with an iOS SDK that matches or exceeds the project’s **minimum deployment** (see the **ToDoApp** target → **General**). |
| **Run destination** | iOS Simulator or a physical iPhone / iPad. |

For running on a **physical device**, set your **Team** and **Bundle Identifier** under **Signing & Capabilities**.

---

## Run locally

1. Open **`ToDoApp.xcodeproj`** in Xcode (**File → Open** or double-click the file).
2. Choose a simulator or connected device in the scheme/run destination menu.
3. **⌘R** to build and run. Use **⌘B** to build only.

---

## Repository layout

| Path | Purpose |
|------|---------|
| `ToDoApp/App/` | `@main` app entry (`ToDoAppApp`), SwiftData `modelContainer` |
| `ToDoApp/DataModel/` | `Category` and `Item` SwiftData models |
| `ToDoApp/Features/Categories/` | Home screen: category grid, selection, reorder sheet |
| `ToDoApp/Features/Tasks/` | Task list (filters, edit, add task) |
| `ToDoApp/Assets.xcassets/` | App icon and image assets |
| `ToDoApp/Base.lproj/` | Launch screen |
| `ToDoApp.xcodeproj/` | Xcode project and shared scheme |

---

## Behavior

**Categories**

- Two-column grid with category name and task count  
- Add categories via alert; **Select** for multi-select delete; **Reorder** opens a reorder sheet  
- Header shows the current date and optional display name (stored in `UserDefaults`, key `Key`)  
- Toolbar actions: edit name, select mode, reorder, add category  

**Tasks**

- Segmented filter: **All** · **Completed** · **Pending**  
- Toggle completion with SF Symbols; strikethrough when completed  
- Swipe to delete; with **All** selected, use **Edit** to reorder rows  
- **+** navigates to add a new task  

**Data**

- Persisted on device with **SwiftData** (no remote sync in this project).
