import SwiftUI
import UniformTypeIdentifiers

struct FilePickerButton: View {
    let onFileSelected: (URL) -> Void

    var body: some View {
        Button("Open PST File...") {
            openFile()
        }
        .keyboardShortcut("o", modifiers: .command)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Outlook Data File"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "pst"),
            UTType(filenameExtension: "ost")
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            onFileSelected(url)
        }
    }
}
