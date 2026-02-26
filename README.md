# Free PST Viewer

A free, native macOS application for browsing and viewing Microsoft Outlook data files (.pst and .ost). Built with SwiftUI and [PstReader](https://github.com/hughbe/PstReader), a pure Swift implementation of the MS-PST specification.

## Download

Download the latest release from the [Releases page](https://github.com/rlorenzo/Free-PST-Viewer/releases/latest).

**First launch (Gatekeeper):** This app is not signed with an Apple Developer certificate, so macOS will block it by default. To open it:

1. Download and open the `.dmg`, then drag **Free PST Viewer** to your Applications folder
2. Right-click (or Control-click) the app and choose **Open**
3. Click **Open** in the security dialog

This is only required on first launch — after that the app opens normally.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.0 or later (for building from source)

## Getting Started

```bash
git clone https://github.com/rexlorenzo/Free-PST-Viewer.git
cd Free-PST-Viewer

# Install git hooks (SwiftLint pre-commit)
chmod +x scripts/install-hooks.sh
./scripts/install-hooks.sh

# Open in Xcode
open FreePSTViewer.xcodeproj
```

SPM dependencies (PstReader and its transitive deps) resolve automatically when Xcode opens the project.

Build and run with **Cmd+R**, or from the command line:

```bash
xcodebuild build -project FreePSTViewer.xcodeproj -scheme FreePSTViewer -destination "platform=macOS"
```

## Architecture

MVVM with a thin service layer wrapping PstReader:

```
FreePSTViewer/
├── Models/        # App-specific types (PSTViewerError, EmailSortOrder, etc.)
├── Views/         # SwiftUI views (FolderTreeView, EmailListView, etc.)
├── ViewModels/    # Observable view models (PSTViewModel, FolderViewModel, etc.)
└── Services/      # PSTParserService, SearchService, ExportService
```

PstReader handles all PST binary parsing, MAPI property resolution, and lazy data loading via memory-mapped I/O.

## Supported File Formats

| Format | Extension | Description |
| ------ | --------- | ----------- |
| Unicode PST | `.pst` | Outlook Personal Storage (Unicode, post-2003) |
| ANSI PST | `.pst` | Outlook Personal Storage (ANSI, pre-2003) |
| OST | `.ost` | Offline Storage Table (Exchange cached mode) |

Files can be opened via the **Open PST File...** button (Cmd+O) or by dragging a `.pst`/`.ost` file onto the application window.

## Features

- **Folder navigation** — hierarchical tree with expand/collapse and item counts
- **Email viewing** — sortable list with HTML rendering, plain text fallback, and inline images
- **Search** — metadata and optional body search with date range and sender filters
- **Export** — single or batch export to `.eml` (RFC 2822) or `.txt` with timestamp preservation
- **Attachments** — save or open attachments with dangerous file type warnings
- **Full headers** — expandable transport headers or MAPI property fallback with copy-to-clipboard
- **Accessibility** — VoiceOver labels, keyboard navigation (Cmd+O), drag-and-drop file opening

## Testing

```bash
xcodebuild test -project FreePSTViewer.xcodeproj -scheme FreePSTViewer -destination "platform=macOS"
```

Test fixtures (ANSI, Unicode, and OST format PST files) are in `FreePSTViewerTests/Fixtures/`.

## License

MIT License

Copyright (c) 2025 Rex Lorenzo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
