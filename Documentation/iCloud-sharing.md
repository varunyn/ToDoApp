# iCloud list sharing

## Using sharing

Open a private category and tap **Share List**. The app publishes that list to your iCloud account, retains the original private list as a backup, and opens Apple's invitation screen. Send an invitation through Messages or another supported app. The recipient needs Toki installed and an iCloud account; accepting the invitation adds the list to **Shared lists** on the home screen.

Only the selected list is shared. Invitations are private and allow invited people to edit. Use **List options → Manage sharing** to manage access. Owners can delete a shared list for everyone; participants can leave it. If access ends, the app retains a readable saved copy with editing disabled. **Profile → Private backups** can restore the owner's original private data from when sharing began; this backup does not contain later collaboration edits.

Tasks support adding, editing titles and priorities, completing, deleting, searching, and filtering. Completed tasks appear below unfinished tasks. The home totals and widget include shared tasks; tapping a shared widget task opens the app to edit it. Private widget tasks remain interactive.

## Apple Developer setup

1. Open `ToDoApp.xcodeproj`. Confirm signing uses the intended Apple Developer team and the main bundle ID is `com.varunyadav.toki`. The widget bundle ID is `com.varunyadav.toki.ToDoWidgetExtension`. `Configuration/Local.xcconfig`, if present, overrides the shared configuration; keep those values aligned.
2. In the Apple Developer portal, create or verify `iCloud.com.varunyadav.toki`. Enable iCloud / CloudKit on both App IDs and associate the container with them. Confirm both App IDs also have access to `group.com.varunyadav.toki`.
3. Refresh provisioning profiles or allow Xcode automatic signing to regenerate them. The repository's entitlements contain CloudKit and App Groups; the app's Info.plist declares `CKSharingSupported` and its configured container identifier. Adding identifiers to files alone does not create or authorize the container in the developer account.
4. Run a signed development build with iCloud enabled. Create a private category and task, then share it. Verify the development schema in [CloudKit Console](https://icloud.developer.apple.com/). The private SwiftData store has its own generated `CD_` record types; collaboration uses the explicit types listed below. Retain the generated SwiftData types and indexes when deploying.
5. Test with **two different Apple accounts**, with both builds using the same CloudKit environment. Test a cold-start invitation, simultaneous edits, offline edits followed by reconnection, task deletion while another device is offline, stopping sharing, leaving, and deleting a shared list. Test a second device on the owner's account as well.
6. After development testing, review and deploy the development schema to **Production** before testing the App Store/TestFlight build. Schema deployment does not copy development users' records into production. See [Apple's deployment guide](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).

The container association, provisioning, schema deployment, and live two-account test require developer-account access. Compilation and local tests do not establish that these server-side prerequisites are configured.

### Collaboration record types

Each list gets its own custom zone, named `TokiList-<UUID>`, shared with a zone-wide `CKShare`. The private SwiftData zone is never shared.

| Record type | Fields | CloudKit types |
| --- | --- | --- |
| `TokiSharedList` | `name` | String |
| `TokiSharedTask` | `title` | String |
| `TokiSharedTask` | `isDone`, `priority`, `order`, `isDeleted` | Int64 |
| `TokiSharedTask` | `createdAt` | Date/Time |

The list root has record name `list`; task record names are stable UUID strings. The implementation reads zone changes, so these collaboration fields do not need query indexes. Do not make these private records publicly readable or writable; CKShare supplies participant access.

## Sync and storage behavior

- Shared lists use CloudKit directly because SwiftData's automatic iCloud integration does not expose user-to-user sharing. Private lists keep their SwiftData store. CloudKit-compatible defaults and optional relationships allow existing private data to migrate automatically.
- A separate, atomic JSON cache is scoped to the iCloud user's record ID. Its pending fields form a durable outbox. Local edits are saved before the UI changes and remain queued when uploads fail. Cached list data and archived zone-change tokens are written together; previous array-format caches upgrade without discarding pending edits.
- Sync runs on foreground activation, every 30 seconds while the app is active, after edits, after accepting invitations, and on manual refresh. Shared lists do not currently receive background push updates. The widget displays the app's most recently saved shared cache.
- Cached lists can appear on an offline launch only when the current local iCloud identity token matches the token stored after successful CloudKit identity verification. They show a waiting-to-verify status and remain read-only until their zones reconcile. If the local identity token is unavailable or mismatched, the cache remains hidden; older installations need one successful online verification to establish this marker. Already verified and reconciled lists remain available for offline editing. Account-change notifications clear the active cache selection immediately, and the widget applies the same identity gate.
- Uploads change only fields edited locally. Edits to different fields can coexist; competing edits to the same field use the last CloudKit write. A task's deletion marker wins over offline edits, preventing deleted tasks from returning.
- Sync pages through incremental zone changes using its persisted token, preserving unchanged tasks and applying explicit deletions. A missing or expired token triggers a full fetch. Uploads check the server record version and retry conflicts against the current record so unrelated edits and deletion markers are preserved.
- Publication is retryable. Its zone identifier is saved before upload, and the list root is created after the initial tasks finish uploading. Original private data is retained rather than deleted. If publication finishes but the app closes before moving the category out of the private UI, the home screen completes that transition when it discovers the published list.
- **Clear private lists** affects visible private categories only. Shared lists and original backups have their own explicit actions.
- The app and widget always reopen the same named app-group SwiftData store, with a same-store retry without CloudKit if initialization fails. If neither configuration can open it, the app shows a retry screen rather than opening a separate empty database.

## Local validation

Run the shared-list merge, incremental changes, cache-file migration, saved-outbox, sorting, and private-store migration tests:

```sh
xcodebuildmcp swift-package test --package-path "$PWD"
```

Build and run with the `.xcodeproj` using the XcodeBuildMCP simulator workflow. A simulator build does not validate invitations or live CloudKit access. Finish the two-account development and TestFlight checks before release.

Additional release checks for the audit fixes:

- After an online sync, relaunch offline with the same iCloud identity and confirm cached lists are visible with editing disabled until access reconciles. Switch accounts and confirm the previous account’s cache is never displayed.
- Edit a private task’s title, completion, and priority, then dismiss the sheet: the original values must remain. A blank draft title must disable Done; a valid Done must persist all edits.
- Keep a private task list open while another device adds or deletes a task, and confirm membership updates without navigating away.
- Enable Reduce Motion and VoiceOver; verify Quick Add avoids slide/scale effects and category selection announces selected state.
- With an expired sync token, confirm a full refresh retains pending edits and establishes a new cursor. Check deletion and concurrent edits with two accounts.

### Audit fix validation — 2026-10-07

- All 10 Swift Testing tests passed, including incremental reconciliation, atomic cache/token persistence, and legacy cache migration with pending edits retained.
- The app and widget built successfully for the iOS 26.5 simulator using `ToDoApp.xcodeproj`, without compiler warnings. The app installed and launched successfully.
- Interactive UI verification remains outstanding: XcodeBuildMCP's UI helper cannot load SimulatorKit with this Xcode installation, and native automation does not expose Simulator.
- Live CloudKit invitations, account changes, offline recovery, and two-account conflict checks remain unverified. Complete the release checks above on signed devices.

### Validation status — 2026-10-05

- Six Swift Testing tests passed, including migration of the previous private-store schema with its task relationship intact.
- The app and widget compiled for the iOS 26.5 simulator; the app launched and its home screen was visually checked.
- An unsigned Release build for physical iPhones passed.
- Signed-device validation remains blocked. The command-line build reports no usable account for team `AG5WJCE73V` and no matching development profiles. Inspection of Xcode confirms the account is signed in and the Avee Pansara team is listed with the Admin role, but **Certificates, Identifiers, & Profiles** has a red X. The confirmed publishing team is retained; developer-resource access or an account-holder-managed signing workflow is required rather than simply adding the same account again.
- Live CloudKit invitations, two-account collaboration, server configuration, and production schema deployment remain unverified.
