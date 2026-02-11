# Design Document

## Overview

The Free PST Viewer will be transformed from a basic SwiftUI app into a comprehensive PST file browser and email viewer. The design leverages SwiftUI's NavigationSplitView for a three-pane interface (folder tree, email list, email detail) and integrates with native macOS file handling capabilities.

The architecture follows MVVM pattern with SwiftUI views, view models for business logic, and a thin service layer that wraps the PstReader library for PST file parsing.

## PST Parsing Library

The app uses [PstReader](https://github.com/hughbe/PstReader) (MIT license), a pure Swift implementation of the [MS-PST] specification. Version 1.0.2+ includes:

- **Memory-mapped I/O** via `PstFile(contentsOf: URL)` — large PST files are not loaded entirely into RAM
- **Convenience API** — `.subjectText`, `.senderDisplayString`, `.date`, `.bodyHtmlString`, `.filename`, etc.
- **Lazy loading** — folder contents, message details, and attachment data are loaded on demand
- **Full format support** — ANSI PST, Unicode PST, and OST files

PstReader depends on [SwiftMAPI](https://github.com/hughbe/SwiftMAPI) which provides hundreds of MAPI property accessors (subject, sender, body, bodyHtml, importance, messageFlags, attachments, recipients, etc.) via the `MessageStorage` protocol. All `PstFile.Message`, `PstFile.Folder`, `PstFile.Attachment`, and `PstFile.Recipient` types conform to this protocol.

### Key PstReader APIs

```swift
// Open a PST file with memory-mapped I/O
let pst = try PstFile(contentsOf: url)

// Navigate folder tree
let root = pst.rootFolder
for child in root.children {
    print(child.name)           // convenience: displayName
    print(child.emailCount)     // convenience: contentCount
    print(child.hasSubfolders)  // convenience: subfolders ?? false
}

// List messages in a folder (metadata only — lazy)
let messages = try folder.getMessages()
for msg in messages {
    print(msg.subjectText)          // convenience: subject
    print(msg.senderDisplayString)  // "Name <email>"
    print(msg.date)                 // convenience: messageDeliveryTime
    print(msg.sizeInBytes)          // convenience: messageSize
}

// Load full message details (body, recipients, attachments)
let detailed = try message.getMessageDetails()
print(detailed.bodyText)        // convenience: body (plain text)
print(detailed.bodyHtmlString)  // convenience: bodyHtml decoded to String
for recipient in detailed.recipients {
    print(recipient.name)       // convenience: displayName
    print(recipient.address)    // convenience: emailAddress
    print(recipient.type)       // convenience: recipientType (To/CC/BCC)
}

// Load attachment data (on demand)
let attachment = try detailed.attachments[0].getAttachmentDetails()
print(attachment.filename)      // convenience: attachLongFilename ?? attachFilename
print(attachment.sizeInBytes)   // convenience: attachSize
let data = attachment.fileData  // convenience: attachDataBinary

// All underlying MAPI properties also accessible directly:
let messageId: String? = message.internetMessageId
let importance: MessageImportance? = message.importance
let flags: MessageFlags? = message.messageFlags
```

## Architecture

### High-Level Architecture

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI Views │    │   View Models   │    │    Services     │
│                 │    │                 │    │                 │
│ • FilePickerView│◄──►│ • PSTViewModel  │◄──►│ • PSTParser     │
│ • FolderTreeView│    │ • FolderViewModel│    │   (PstReader)   │
│ • EmailListView │    │ • EmailViewModel│    │ • SearchService │
│ • EmailDetailView│   │ • SearchViewModel│   │ • ExportService │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   PstReader     │
                    │   (SPM Dep)     │
                    │                 │
                    │ • PstFile       │
                    │ • Folder        │
                    │ • Message       │
                    │ • Attachment    │
                    │ • Recipient     │
                    └─────────────────┘
```

### Component Responsibilities

- **Views**: SwiftUI views handling user interface and user interactions
- **View Models**: Business logic, state management, and coordination between views and services
- **Services**: Thin wrappers around PstReader for async/background operations, plus search and export logic
- **PstReader**: Pure Swift PST parsing library (SPM dependency) — handles all binary format parsing, MAPI property resolution, and data extraction

## Components and Interfaces

### 1. Data Models

The app uses PstReader's types directly rather than defining duplicate model types. View models wrap these types with observable state.

No custom data models are needed for PST structures — PstReader provides:

- `PstFile` — the parsed PST file
- `PstFile.Folder` — folder with children, messages, and MAPI properties
- `PstFile.Message` — email with recipients, attachments, and MAPI properties
- `PstFile.Attachment` — attachment with file data and MAPI properties
- `PstFile.Recipient` — recipient with name, address, and type

App-specific types:

```swift
enum EmailSortOrder {
    case dateAscending, dateDescending
    case subjectAscending, subjectDescending
    case senderAscending, senderDescending
    case sizeAscending, sizeDescending
}

enum ExportFormat {
    case eml, txt
}

struct SearchFilters {
    let dateRange: DateInterval?
    let sender: String?
    let folder: PstFile.Folder?
    let hasAttachments: Bool?
}
```

### 2. Services

#### PSTParserService

PstReader types (`PstFile`, `PstFile.Folder`, `PstFile.Message`, etc.) are not `Sendable` — they hold internal references to the memory-mapped file data. The parser service runs expensive operations on a dedicated serial `DispatchQueue`, bridged to `async/await` via `withCheckedThrowingContinuation`. This avoids `Sendable` enforcement (GCD closures are not `@Sendable`) while keeping parse work off the main thread. `@MainActor` view models call the async methods and receive results on the main thread automatically.

```swift
class PSTParserService {
    private let queue = DispatchQueue(label: "com.freepstviewer.parser", qos: .userInitiated)

    func loadPSTFile(from url: URL) async throws -> PstFile {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try PstFile(contentsOf: url) }) }
        }
    }

    func getMessages(from folder: PstFile.Folder) async throws -> [PstFile.Message] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try folder.getMessages() }) }
        }
    }

    func getMessageDetails(for message: PstFile.Message) async throws -> PstFile.Message {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try message.getMessageDetails() }) }
        }
    }

    func getAttachmentDetails(for attachment: PstFile.Attachment) async throws -> PstFile.Attachment {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try attachment.getAttachmentDetails() }) }
        }
    }
}
```

#### SearchService

Search uses a staged approach to avoid loading full message bodies unnecessarily:

1. **Metadata search** (fast): Match against `.subjectText`, `.senderDisplayString`, `.date` — no `getMessageDetails()` needed
2. **Body search** (on-demand): Only load `.bodyText` via `getMessageDetails()` when the user explicitly enables "Search message body"
3. **Cancellation**: Long-running searches check `Task.isCancelled` between folder iterations for cooperative cancellation

All PstReader calls within search go through `PSTParserService`'s serial queue to maintain the single-queue access pattern.

```swift
struct SearchService {
    private let parserService: PSTParserService

    func searchEmails(
        in folders: [PstFile.Folder],
        query: String,
        filters: SearchFilters,
        includeBody: Bool = false
    ) async throws -> [PstFile.Message]
}
```

#### ExportService

```swift
struct ExportService {
    func exportEmail(_ message: PstFile.Message, to url: URL, format: ExportFormat) throws
    func saveAttachment(_ attachment: PstFile.Attachment, to url: URL) throws
    func openAttachment(_ attachment: PstFile.Attachment) throws  // Save to temp dir, open via NSWorkspace
}
```

### 3. View Models

#### PSTViewModel

```swift
@MainActor
class PSTViewModel: ObservableObject {
    @Published var currentPSTFile: PstFile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let parser = PSTParserService()

    func loadPSTFile(from url: URL) async
    func closePSTFile()
}
```

#### FolderViewModel

```swift
@MainActor
class FolderViewModel: ObservableObject {
    @Published var selectedFolder: PstFile.Folder?
    @Published var expandedFolderIDs: Set<String> = []  // Keyed by folder index path, not display name

    func selectFolder(_ folder: PstFile.Folder)
    func toggleFolderExpansion(id: String)
    func folderID(at indexPath: [Int]) -> String  // Computes stable ID from tree position
}
```

#### EmailListViewModel

```swift
@MainActor
class EmailListViewModel: ObservableObject {
    @Published var emails: [PstFile.Message] = []
    @Published var selectedEmail: PstFile.Message?
    @Published var sortOrder: EmailSortOrder = .dateDescending
    @Published var isLoading: Bool = false

    func loadEmails(for folder: PstFile.Folder) async
    func selectEmail(_ email: PstFile.Message)
    func sortEmails(by order: EmailSortOrder)
}
```

### 4. Views

#### MainContentView

```swift
struct MainContentView: View {
    @StateObject private var pstViewModel = PSTViewModel()
    @StateObject private var folderViewModel = FolderViewModel()
    @StateObject private var emailListViewModel = EmailListViewModel()

    var body: some View {
        NavigationSplitView {
            FolderTreeView()
        } content: {
            EmailListView()
        } detail: {
            EmailDetailView()
        }
    }
}
```

## Email Content Handling

PstReader's lazy loading maps directly to the UI layers:

- **Folder tree**: `pst.rootFolder` loads folder hierarchy with metadata (name, count). No email data loaded.
- **Email list**: `folder.getMessages()` returns messages with list-level properties (subject, sender, date, size) from the Contents Table. No body/attachment data loaded.
- **Email detail**: `message.getMessageDetails()` loads the full message including body, recipients, and attachment metadata from the Message Object PC and subnodes.
- **Attachment download**: `attachment.getAttachmentDetails()` loads the actual binary data from the Attachment Object PC.

This three-level lazy loading is built into PstReader and requires no additional implementation.

### HTML Email Security

When rendering HTML email content via WKWebView:

- **Disable JavaScript** — set `javaScriptEnabled = false` on the WKWebView configuration
- **Block remote content** — configure `WKWebViewConfiguration` to prevent all network loads (blocks tracking pixels, remote images, external stylesheets)
- **Allow embedded images** — resolve `cid:` references to inline attachment data only
- **No navigation** — disable link navigation; open clicked links in the system browser instead

## Error Handling

### Error Types

```swift
enum PSTViewerError: LocalizedError {
    case fileNotFound
    case invalidFileFormat(underlying: Error)
    case parseError(String)
    case exportError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .invalidFileFormat(let error):
            return "Invalid Outlook data file: \(error.localizedDescription)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .exportError(let message):
            return "Export error: \(message)"
        }
    }
}
```

PstReader throws `PstReadError` for format-level issues (invalid magic, corrupted heap, missing nodes, etc.). The service layer catches these and wraps them in `PSTViewerError` for user-friendly display.

### Error Handling Strategy

- **User-Facing Errors**: Display alerts with clear, actionable messages
- **Recoverable Errors**: Attempt to load partial content and notify user
- **Critical Errors**: Graceful degradation with option to select different file
- **Logging**: Comprehensive error logging for debugging

## Testing Strategy

### Unit Testing

- **Service Tests**: Test PSTParserService, SearchService, and ExportService with sample PST files
- **View Model Tests**: Test business logic and state management

### Integration Testing

- **File Loading**: Test with various PST file sizes and formats (ANSI, Unicode)
- **Error Scenarios**: Test with corrupted, incomplete, or invalid PST files

### UI Testing

- **Navigation**: Test folder tree navigation and email selection
- **Search**: Test search functionality across different criteria
- **Export**: Test email and attachment export functionality

### Test Data Strategy

- Use PstReader's existing test PST files (50+ files in various formats) as reference
- Create additional sample PST files for app-specific edge cases

### Accessibility Testing

- **VoiceOver**: Test screen reader compatibility
- **Keyboard Navigation**: Ensure full keyboard accessibility
- **High Contrast**: Test with high contrast display settings
- **Text Scaling**: Test with various text size settings

## Implementation Notes

### SPM Dependency Setup

Add to the app's Package.swift or Xcode project:

```swift
.package(url: "https://github.com/hughbe/PstReader", from: "1.0.2"),
```

This pulls in PstReader and its transitive dependencies (DataStream, SwiftMAPI, WindowsDataTypes) automatically.

### Sandbox Entitlements

The app needs read-write access for user-selected files (currently read-only):

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

This is required for export/save functionality (Requirement 7).

### SwiftData Removal

The current template uses SwiftData with a placeholder `Item` model. This should be removed entirely — PST files are read-only and do not need persistence.

### Performance Considerations

- PstReader uses memory-mapped I/O — the OS manages paging automatically
- Folder/message/attachment data loads lazily — no upfront cost for large files
- Parser operations run on a background `DispatchQueue` to keep UI responsive
- Cache message details for recently viewed emails
- Implement virtual scrolling for folders with many emails
- **Large folder UI chunking**: `folder.getMessages()` eagerly fetches all metadata from the Contents Table (not body/attachment data). For folders with 10,000+ messages, display in UI chunks (500 rows at a time) via array slicing with scroll-triggered rendering
- **Partial corruption recovery**: If `getMessages()` or `getMessageDetails()` throws for individual items, skip the corrupted entry, display available content, and show a non-blocking warning banner

### macOS Integration

- Use NSOpenPanel for native file selection
- Implement drag-and-drop support for PST files
- Support macOS file associations for .pst and .ost files
- Follow macOS Human Interface Guidelines for consistent UX
