# Free PST Viewer

A native macOS application for browsing and viewing Microsoft Outlook PST (Personal Storage Table) files. Built with SwiftUI, this app provides a familiar mail client interface for accessing archived Outlook data without requiring Microsoft Outlook.

## Features

- **Browse PST Files**: Native macOS file picker to select and open .pst files
- **Folder Navigation**: Hierarchical folder tree view with expand/collapse functionality
- **Email Viewing**: Three-pane interface (folders, email list, email detail) similar to traditional mail clients
- **Search Functionality**: Full-text search across email content, subjects, and senders with filtering options
- **Attachment Support**: View and save email attachments with proper file type handling
- **Export Options**: Export individual emails or attachments in various formats (.eml, .txt)
- **Performance Optimized**: Efficient handling of large PST files with lazy loading and caching
- **Native macOS Integration**: Follows macOS Human Interface Guidelines with proper accessibility support

## Screenshots

*Screenshots will be added as the application is developed*

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)
- Swift 5.9 or later

## Installation

### Build from Source

1. **Clone the repository:**

   ```bash
   git clone https://github.com/[username]/free-pst-viewer.git
   cd free-pst-viewer
   ```

2. **Open in Xcode:**

   ```bash
   open "Free PST Viewer.xcodeproj"
   ```

3. **Install Dependencies:**
   The project will automatically resolve Swift Package Manager dependencies when opened in Xcode.

4. **Build and Run:**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run
   - Or use `Cmd + B` to build only

### Build Configuration

The project includes the following build configurations:

- **Debug**: For development with debugging symbols and logging
- **Release**: Optimized build for distribution

## Usage

1. **Launch the Application**
   - Open Free PST Viewer from your Applications folder or run from Xcode

2. **Open a PST File**
   - Click "Browse" or use `Cmd + O` to open the file picker
   - Navigate to and select your .pst file
   - Wait for the file to load (progress indicator will show for large files)

3. **Navigate Your Email**
   - Use the left sidebar to browse folder structure
   - Click folders to view contained emails
   - Select emails from the center list to view content in the detail pane

4. **Search Emails**
   - Use the search bar to find specific emails
   - Apply filters by date, sender, or folder
   - Search results will highlight matching terms

5. **Export Content**
   - Right-click emails to access export options
   - Save attachments using the attachment list in email details
   - Choose from available export formats

## Development

### Project Structure

```
Free PST Viewer/
├── Models/           # Data models (Email, Folder, PST file structures)
├── Views/            # SwiftUI views and UI components
├── ViewModels/       # MVVM view models and business logic
├── Services/         # Core services (PST parsing, search, export)
├── Utilities/        # Helper functions and extensions
└── Resources/        # Assets, localizations, and configuration files
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Data persistence and modeling
- **Combine**: Reactive programming for UI updates
- **Foundation**: Core Swift functionality and file handling
- **libpst**: PST file parsing library (C library with Swift bindings)

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the existing code style
4. Add tests for new functionality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Testing

Run the test suite using Xcode:

```bash
# Run all tests
xcodebuild test -scheme "Free PST Viewer" -destination "platform=macOS"

# Or use Xcode
# Press Cmd + U to run all tests
```

The project includes:

- Unit tests for core functionality
- Integration tests for PST file handling
- UI tests for user interface components
- Performance tests for large file handling

## Known Limitations

- Currently supports PST files created by Outlook 2003 and later
- Large PST files (>2GB) may require additional processing time
- Some advanced Outlook features (rules, categories) are not displayed
- Encrypted PST files are not currently supported

## Roadmap

- [ ] Support for encrypted PST files
- [ ] Advanced search with regular expressions
- [ ] Email threading and conversation view
- [ ] Dark mode support
- [ ] Localization for multiple languages
- [ ] OST file support
- [ ] Batch export functionality

## Troubleshooting

### Common Issues

**"Cannot open PST file" error:**

- Ensure the PST file is not corrupted
- Verify the file is not currently open in Outlook
- Check file permissions

**Slow performance with large files:**

- Close other applications to free up memory
- Consider breaking large PST files into smaller archives
- Ensure sufficient disk space for temporary files

**Missing emails or folders:**

- Some PST files may have structural issues
- Try opening the PST file in Outlook first to verify integrity
- Check if the PST file version is supported

## Support

- Create an issue on [GitHub Issues](https://github.com/[username]/free-pst-viewer/issues)
- Check existing issues for similar problems
- Provide PST file details (size, Outlook version) when reporting issues

## License

This project is licensed under the MIT License - see the [LICENSE](#license) file for details.

---

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
