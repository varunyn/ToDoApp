# Changelog

## [Unreleased]

### Added

- Share individual lists through private iCloud invitations so invited people can add, edit, complete, and delete tasks together.
- Shared lists on the home screen, saved offline edits, sharing management, and shared task summaries in the widget.
- Original private-list backups that can be restored from Profile after sharing begins.

### Changed

- Private data migrates automatically to an iCloud-compatible model; CloudKit container association, provisioning, and production schema deployment are required before releasing sharing.
- Clearing private lists preserves shared lists and their original backups.
- Shared-list sync downloads incremental changes and saves its progress together with the local cache; older caches upgrade automatically.

### Fixed

- Saved shared lists can appear offline when the local iCloud identity matches; they stay read-only until access is verified, with clear status and startup sync errors.
- Storage failures show a retry screen instead of silently switching to a different task database; the widget uses the same shared-store recovery.
- Private task edits remain drafts until Done, so dismissing the editor preserves the original task and blank titles cannot be saved.
- Private task lists follow changes to their category’s tasks without a stale manual row cache.
- Quick Add and task completion respect Reduce Motion, selected categories expose their state to VoiceOver, and small controls have larger tap areas.
