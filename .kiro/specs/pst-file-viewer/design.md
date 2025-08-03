# Design Document

## Overview

The Free PST Viewer will be transformed from a basic SwiftUI app into a comprehensive PST file browser and email viewer. The design leverages SwiftUI's NavigationSplitView for a three-pane interface (folder tree, email list, email detail) and integrates with native macOS file handling capabilities.

The architecture follows MVVM pattern with SwiftUI views, view models for business logic, and service layers for PST file parsing and data management. The app will use Swift's async/await for file operations and Combine for reactive UI updates.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI Views │    │   View Models   │    │    Services     │
│                 │    │                 │    │                 │
│ • FilePickerView│◄──►│ • PSTViewModel  │◄──►│ • PSTParser     │
│ • FolderTreeView│    │ • FolderViewModel│    │ • FileManager   │
│ • EmailListView │    │ • EmailViewModel│    │ • SearchService │
│ • EmailDetailView│   │ • SearchViewModel│   │ • ExportService │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Data Models   │
                    │                 │
                    │ • PSTFile       │
                    │ • Folder        │
                    │ • Email         │
                    │ • Attachment    │
                    └─────────────────┘
```

### Component Responsibilities

- **Views**: SwiftUI views handling user interface and user interactions
- **View Models**: Business logic, state management, and coordination between views and services
- **Services**: Core functionality for PST parsing, file operations, search, and export
- **Data Models**: Swift structs/classes representing PST file structure and email data

## Components and Interfaces

### 1. Data Models

#### PSTFile
```swift
struct PSTFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    var rootFolder: Folder
    var isLoaded: Bool
    var loadingProgress: Double
}
```

#### Folder
```swift
struct Folder: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var subfolders: [Folder]
    var emailCount: Int
    let folderType: FolderType // Inbox, Sent, Drafts, Custom
}

enum FolderType {
    case inbox, sent, drafts, deleted, custom
}
```

#### Email
```swift
struct Email: Identifiable {
    let id = UUID()
    let subject: String
    let sender: EmailAddress
    let recipients: [EmailAddress]
    let date: Date
    let body: EmailBody
    let attachments: [Attachment]
    let size: Int64
    let isRead: Bool
    let importance: EmailImportance
}

struct EmailAddress {
    let name: String?
    let address: String
}

struct EmailBody {
    let plainText: String?
    let htmlContent: String?
    let hasImages: Bool
}

enum EmailImportance {
    case low, normal, high
}
```

#### Attachment
```swift
struct Attachment: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let mimeType: String
    let data: Data
}
```

### 2. Services

#### PSTParserService
```swift
protocol PSTParserService {
    func loadPSTFile(from url: URL) async throws -> PSTFile
    func getFolders(from pstFile: PSTFile) async throws -> [Folder]
    func getEmails(from folder: Folder, in pstFile: PSTFile) async throws -> [Email]
    func getEmailContent(for email: Email, in pstFile: PSTFile) async throws -> Email
}
```

#### SearchService
```swift
protocol SearchService {
    func searchEmails(
        in pstFile: PSTFile,
        query: String,
        filters: SearchFilters
    ) async throws -> [Email]
}

struct SearchFilters {
    let dateRange: DateInterval?
    let sender: String?
    let folder: Folder?
    let hasAttachments: Bool?
}
```

#### ExportService
```swift
protocol ExportService {
    func exportEmail(_ email: Email, to url: URL, format: ExportFormat) async throws
    func saveAttachment(_ attachment: Attachment, to url: URL) async throws
}

enum ExportFormat {
    case eml, txt, pdf
}
```

### 3. View Models

#### PSTViewModel
```swift
@MainActor
class PSTViewModel: ObservableObject {
    @Published var currentPSTFile: PSTFile?
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let pstParser: PSTParserService
    
    func loadPSTFile(from url: URL) async
    func closePSTFile()
}
```

#### FolderViewModel
```swift
@MainActor
class FolderViewModel: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var selectedFolder: Folder?
    @Published var expandedFolders: Set<UUID> = []
    
    func selectFolder(_ folder: Folder)
    func toggleFolderExpansion(_ folder: Folder)
}
```

#### EmailListViewModel
```swift
@MainActor
class EmailListViewModel: ObservableObject {
    @Published var emails: [Email] = []
    @Published var selectedEmail: Email?
    @Published var sortOrder: EmailSortOrder = .dateDescending
    @Published var isLoading: Bool = false
    
    func loadEmails(for folder: Folder) async
    func selectEmail(_ email: Email)
    func sortEmails(by order: EmailSortOrder)
}

enum EmailSortOrder {
    case dateAscending, dateDescending
    case subjectAscending, subjectDescending
    case senderAscending, senderDescending
    case sizeAscending, sizeDescending
}
```

### 4. Views

#### MainContentView
The main view that orchestrates the three-pane layout:
```swift
struct MainContentView: View {
    @StateObject private var pstViewModel = PSTViewModel()
    @StateObject private var folderViewModel = FolderViewModel()
    @StateObject private var emailListViewModel = EmailListViewModel()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with folder tree
            FolderTreeView()
        } content: {
            // Email list
            EmailListView()
        } detail: {
            // Email detail view
            EmailDetailView()
        }
    }
}
```

## Data Models

### PST File Structure Representation

The app will represent PST files using a hierarchical structure that mirrors the original Outlook folder organization:

```
PSTFile
├── Root Folder
    ├── Inbox (System Folder)
    │   ├── Email 1
    │   ├── Email 2
    │   └── Subfolder
    ├── Sent Items (System Folder)
    ├── Drafts (System Folder)
    ├── Deleted Items (System Folder)
    └── Custom Folders
        └── Project Emails
            ├── Email 3
            └── Email 4
```

### Email Content Handling

Emails will be loaded lazily to optimize performance:
- **List View**: Load only metadata (subject, sender, date, size)
- **Detail View**: Load full content including body and attachments when selected
- **Attachments**: Load attachment data only when user requests to view/save

## Error Handling

### Error Types
```swift
enum PSTViewerError: LocalizedError {
    case fileNotFound
    case invalidPSTFormat
    case corruptedFile
    case insufficientMemory
    case parseError(String)
    case exportError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PST file not found"
        case .invalidPSTFormat:
            return "Invalid PST file format"
        case .corruptedFile:
            return "PST file appears to be corrupted"
        case .insufficientMemory:
            return "Insufficient memory to load PST file"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .exportError(let message):
            return "Export error: \(message)"
        }
    }
}
```

### Error Handling Strategy
- **User-Facing Errors**: Display alerts with clear, actionable messages
- **Recoverable Errors**: Attempt to load partial content and notify user
- **Critical Errors**: Graceful degradation with option to select different file
- **Logging**: Comprehensive error logging for debugging

## Testing Strategy

### Unit Testing
- **Model Tests**: Validate data model integrity and relationships
- **Service Tests**: Test PST parsing, search functionality, and export operations
- **View Model Tests**: Test business logic and state management

### Integration Testing
- **File Loading**: Test with various PST file sizes and formats
- **Performance**: Test with large PST files (>1GB) and many emails (>10,000)
- **Error Scenarios**: Test with corrupted, incomplete, or invalid PST files

### UI Testing
- **Navigation**: Test folder tree navigation and email selection
- **Search**: Test search functionality across different criteria
- **Export**: Test email and attachment export functionality

### Test Data Strategy
- Create sample PST files with various structures and content types
- Include edge cases: empty folders, emails without subjects, large attachments
- Test with different PST versions and formats

### Performance Testing
- **Memory Usage**: Monitor memory consumption with large PST files
- **Loading Times**: Measure file loading and folder navigation performance
- **UI Responsiveness**: Ensure UI remains responsive during heavy operations

### Accessibility Testing
- **VoiceOver**: Test screen reader compatibility
- **Keyboard Navigation**: Ensure full keyboard accessibility
- **High Contrast**: Test with high contrast display settings
- **Text Scaling**: Test with various text size settings

## Implementation Notes

### PST File Parsing
Since there's no native Swift PST parser, the implementation will need to:
1. Research existing C/C++ PST libraries that can be bridged to Swift
2. Consider using libpst or similar open-source libraries
3. Implement Swift wrappers around the chosen library
4. Handle memory management carefully when bridging C/C++ code

### Performance Considerations
- Implement virtual scrolling for large email lists
- Use background queues for file I/O operations
- Cache frequently accessed data
- Implement progressive loading for large PST files

### macOS Integration
- Use NSOpenPanel for native file selection
- Implement drag-and-drop support for PST files
- Support macOS file associations for .pst files
- Follow macOS Human Interface Guidelines for consistent UX