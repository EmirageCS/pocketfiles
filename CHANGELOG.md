# Changelog

## [1.1.1] - 2026-04-01

### Changed

- Removed unused SHA-256 legacy migration code — all PINs and answers are now bcrypt-only
- Simplified `PinHasher.verify()` — no longer accepts a `legacySalt` parameter
- `getMasterPinInfo()` now returns `String?` instead of a named record with a redundant salt field

### Infrastructure

- Added GitHub Actions CI workflow — runs `flutter analyze` and `flutter test` on every push and PR; builds release APK on main
- Pinned Flutter version to 3.41.4 in Dockerfile
- Added `.dockerignore` to keep build context lean

---

## [1.1.0] - 2026-03-27

### Added

- Global search screen — find files across all folders in one place
- Folder sort by name or date (in addition to existing custom drag order)
- Swipe-to-share (right) and swipe-to-delete (left) on file tiles
- Total folder size shown on folder card (e.g. "2.4 MB")
- Screenshot and screen recording prevention via `FLAG_SECURE` (Android)
- Multi-file selection — pick several files at once with "Add Files"

### Changed

- PIN length is now flexible: 4–8 digits (was fixed at exactly 4)

### Security

- Wider PIN range (up to 8 digits) allows stronger PINs

---

## [1.0.0] - 2026-03-19

### Features

- Create color-coded folders with a full color palette
- Import any file type from device storage
- Rename and share files directly from the app
- Open files with default device apps
- File size, count, and creation date display
- Sort files by name, date, size, or custom order (persisted per folder)
- Search folders and files instantly with debounced filtering
- Drag and drop reordering for folders and files
- Edit mode for folder management
- Change folder color after creation
- PIN lock for individual folders (4-digit)
- Optional PIN hint for memory aid
- Security question and answer for PIN recovery
- Master PIN to unlock any locked folder
- Brute force protection — 60 second cooldown after 3 failed attempts
- Master PIN brute force protection — 5 minute cooldown
- Security alert showing failed unlock attempts since last visit
- Auto re-lock when app goes to background
- Session-based unlocking — PIN required once per session
- Help sheet with feature walkthrough shown on first launch
- Dark mode following system theme

### Security Features

- bcrypt hashing for PINs and security answers (work factor 10)
- Hashing performed in a background isolate via `compute()`
- Failed attempt logging with timestamps and per-folder tracking
- Last successful unlock tracking to filter stale failed attempts
- Locked folder files can be moved (original deleted) for privacy
