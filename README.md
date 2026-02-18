# Free PST Viewer

A free, native macOS application for browsing and viewing Microsoft Outlook data files (.pst and .ost). Built with SwiftUI and [PstReader](https://github.com/hughbe/PstReader), a pure Swift implementation of the MS-PST specification.

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
