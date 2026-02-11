# Implementation Plan

- [ ] 0. Set up project infrastructure and CI
  - Add SwiftLint via SPM plugin or Homebrew; create `.swiftlint.yml` with project conventions (line length, naming, etc.)
  - Add a pre-commit hook (via a `scripts/install-hooks.sh` bootstrap script) that runs SwiftLint `--strict` on staged `.swift` files
  - Create a GitHub Actions CI workflow (`.github/workflows/ci.yml`): build + run all tests on every push and PR
  - Set up the `Free PST ViewerTests` test target with a shared `TestHelpers/` group (e.g., sample PST fixture loader, assertion helpers)
  - Copy small fixture files from PstReader's test resources (`PstReader/Tests/PstReaderTests/Resources/`) into `Free PST ViewerTests/Fixtures/`:
    - `farnulfo/pst-exp/test_ansi.pst` — ANSI format coverage
    - `farnulfo/pst-exp/test_unicode.pst` — Unicode format coverage
    - `hughbe/pstreadertests@outlook.com.ost` — OST format coverage
    - `aranetic/process-pst/four_nesting_levels.pst` — nested folder hierarchy
  - Document the bootstrap steps in the project README (run `scripts/install-hooks.sh`, required Xcode version, etc.)

- [ ] 1. Add PstReader dependency and remove SwiftData scaffolding
  - Add SPM dependency: `https://github.com/hughbe/PstReader` (from: `1.0.2`)
  - Remove `Item.swift` model and SwiftData `modelContainer` from `Free_PST_ViewerApp.swift`
  - Update entitlements to `com.apple.security.files.user-selected.read-write`
  - Verify the project builds with `import PstReader`
  - Verify CI workflow passes (green build + SwiftLint + tests)
  - _Requirements: 1.4_

- [ ] 2. Create service layer and app-specific types
  - Create `PSTParserService` as non-isolated class with background `DispatchQueue` + `async/await` bridge (avoids `Sendable` issues with PstReader types)
  - Create `SearchService` with full-text search across messages
  - Create `ExportService` with .eml and .txt export support
  - Define `EmailSortOrder`, `ExportFormat`, and `SearchFilters` types
  - Create `PSTViewerError` enum wrapping `PstReadError` for user-friendly messages
  - _Requirements: 1.4, 1.5, 5.1, 7.1, 7.2_

- [ ] 3. Implement file picker and PST loading
  - Create FilePickerView with native macOS NSOpenPanel integration
  - Add file type filtering to show .pst and .ost files (PstReader supports both)
  - Implement `PSTViewModel` with `loadPSTFile(from:)` using `PstFile(contentsOf:)`
  - Add error handling for invalid file selection
  - Write unit tests for file loading
  - _Requirements: 1.1, 1.2, 1.3, 1.5_

- [ ] **Milestone A — Core foundation quality gate**
  - All tests pass in CI; SwiftLint reports zero violations
  - PSTParserService can open a fixture PST and return folders/messages in tests
  - File picker → folder tree → email list flow works end-to-end in a manual smoke test

- [ ] 4. Implement folder tree view model and UI
  - Create `FolderViewModel` with folder selection and expansion state
  - Create `FolderTreeView` displaying `PstFile.Folder` hierarchy using `.name`, `.emailCount`, `.hasSubfolders`
  - Add expand/collapse functionality for folders with children
  - Implement folder selection highlighting
  - Show empty folder message when `emailCount == 0`
  - Write unit tests for folder view model logic
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 5. Create email list view model and UI
  - Create `EmailListViewModel` loading messages via `parserService.getMessages(from: folder)`
  - Implement EmailListView with table display using `.subjectText`, `.senderDisplayString`, `.date`, `.sizeInBytes`
  - Add sortable columns using `EmailSortOrder`
  - Implement email selection and highlighting
  - Add loading indicators for email list operations
  - Write unit tests for email list and sorting
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 6. Implement email detail view and content loading
  - Create EmailDetailView displaying full email content
  - Load details via `parserService.getMessageDetails(for: message)` on selection
  - Display headers using `.subjectText`, `.senderDisplayString`, `.toRecipients`, `.ccRecipients`, `.date`
  - Render HTML body via `.bodyHtmlString` using WKWebView, fall back to `.bodyText`
  - Configure WKWebView security: disable JavaScript, block remote content, resolve `cid:` for inline images only
  - List attachments with `.filename` and `.sizeInBytes`
  - Write unit tests for email content loading
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.6_

- [ ] **Milestone B — Read path quality gate**
  - All tests pass in CI; SwiftLint clean
  - Full read flow works: open PST → browse folders → view email list → read email detail with HTML rendering
  - Unit test coverage exists for FolderViewModel, EmailListViewModel, and email content loading

- [ ] 7. Add attachment handling functionality
  - Implement attachment save via `parserService.getAttachmentDetails(for: attachment)` then writing `.fileData` to disk
  - Add NSSavePanel with original `.filename` pre-filled
  - Implement attachment open: save to temp directory, open via `NSWorkspace.shared.open()`, clean up temp files on app exit
  - Handle open failures: missing app association, sandboxed file access errors
  - Support embedded image display in HTML email content
  - Add error handling for attachment operations
  - Write unit tests for attachment functionality
  - _Requirements: 4.4, 4.5, 4.6, 7.3_

- [ ] 8. Implement search functionality
  - Implement `SearchService` (async) with staged search: metadata first (`.subjectText`, `.senderDisplayString`), body search (`.bodyText`) opt-in only
  - Search runs via `PSTParserService` background queue; cooperative cancellation via `Task.isCancelled` between folder iterations
  - Create `SearchViewModel` for managing search state
  - Add search UI components (search bar, date range picker, sender filter, "search body" toggle)
  - Implement search result highlighting
  - Handle empty results and search clearing
  - Write unit tests for search functionality
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [ ] 9. Add export and save functionality
  - Implement `ExportService` with .eml and .txt export formats
  - Preserve original timestamps on exported files using `FileManager.setAttributes(_:ofItemAtPath:)` with `.creationDate` and `.modificationDate` from message `.date`
  - Add context menu for email export options
  - Implement batch export for multiple selected emails
  - Implement attachment save with NSSavePanel
  - Write unit tests for export operations including timestamp preservation verification
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [ ] **Milestone C — Feature-complete quality gate**
  - All tests pass in CI; SwiftLint clean
  - Attachments, search, and export all functional end-to-end
  - Unit tests exist for SearchService, ExportService, and attachment handling

- [ ] 10. Create main application view integration
  - Update ContentView to use NavigationSplitView with three panes
  - Integrate FilePickerView, FolderTreeView, EmailListView, and EmailDetailView
  - Implement view model coordination and data flow
  - Add toolbar with Open File button and search bar
  - Write integration tests for main view functionality
  - _Requirements: 1.1, 1.6, 2.1, 3.1, 4.1_

- [ ] 11. Implement performance optimizations
  - Add virtual scrolling (LazyVStack) for large email lists
  - Implement UI chunking for large folders: `folder.getMessages()` eagerly fetches all metadata; display in 500-row slices with scroll-triggered rendering
  - Implement message detail caching for faster navigation
  - All PstReader access routed through `PSTParserService` serial queue — no direct `Task.detached` PstReader calls
  - Add partial corruption recovery: skip failed messages/folders, show non-blocking warning banner
  - Profile memory usage with large PST files (memory-mapped I/O handles most of this)
  - Write performance tests
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ] 12. Add comprehensive error handling and user feedback
  - Implement error alert displays wrapping PstReadError in PSTViewerError
  - Add loading indicators and progress feedback for long operations
  - Add user-friendly error messages with recovery suggestions
  - Write tests for error handling scenarios
  - _Requirements: 1.5, 6.5, 6.6_

- [ ] 13. Implement full header view functionality
  - Add option to view all MAPI properties via `message.getProperty(id:)`
  - Display RFC 822 transport headers via `.transportMessageHeaders` when available, with fallback to MAPI property display
  - Create expandable header section in email detail view
  - Display technical headers (Message-ID via `.internetMessageId`, importance, flags, etc.)
  - Add copy functionality for header information
  - Write unit tests for header display
  - _Requirements: 4.7_

- [ ] 14. Add final UI polish and accessibility features
  - Implement proper keyboard navigation throughout the app
  - Add VoiceOver support and accessibility labels
  - Ensure proper focus management and tab order
  - Add support for high contrast and text scaling
  - Implement drag-and-drop support for PST files
  - Write accessibility tests and manual testing procedures
  - _Requirements: 1.1, 2.2, 3.4, 4.1_

- [ ] **Milestone D — Release quality gate**
  - All tests pass in CI; SwiftLint clean; zero compiler warnings
  - Performance profiled with a large PST (10k+ emails) — no UI hangs
  - Accessibility audit complete (VoiceOver, keyboard-only navigation)
  - README documents build instructions, hook setup, and supported file formats
