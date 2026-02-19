import AppKit
import Foundation
@preconcurrency import PstReader

/// Handles attachment save and open operations.
@MainActor
class AttachmentService {
    private let parserService: PSTParserService
    private var tempFiles: [URL] = []

    init(parserService: PSTParserService) {
        self.parserService = parserService
    }

    /// Saves an attachment to a user-chosen location via NSSavePanel.
    func saveAttachmentWithPanel(
        _ attachment: PstFile.Attachment
    ) async throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = attachment.filename ?? "Untitled"
        guard panel.runModal() == .OK,
              let url = panel.url else { return }
        try await saveAttachment(attachment, to: url)
    }

    /// Loads attachment details and writes file data to the given URL.
    func saveAttachment(
        _ attachment: PstFile.Attachment,
        to url: URL
    ) async throws {
        let detailed = try await parserService
            .getAttachmentDetails(for: attachment)
        guard let data = detailed.fileData else {
            throw PSTViewerError.attachmentError(
                "No data available for this attachment."
            )
        }
        try data.write(to: url)
    }

    /// Opens an attachment by saving to a temp directory and
    /// launching with the default app.
    func openAttachment(
        _ attachment: PstFile.Attachment
    ) async throws {
        let detailed = try await parserService
            .getAttachmentDetails(for: attachment)
        guard let data = detailed.fileData else {
            throw PSTViewerError.attachmentError(
                "No data available for this attachment."
            )
        }
        let rawFilename = detailed.filename ?? "attachment"
        // Sanitize to a safe basename: strip path components
        // and traversal sequences to prevent directory escape.
        let filename = URL(fileURLWithPath: rawFilename)
            .lastPathComponent
            .replacingOccurrences(of: "..", with: "_")
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "FreePSTViewer", isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let tempURL = tempDir.appendingPathComponent(filename)
        try data.write(to: tempURL)
        tempFiles.append(tempURL)

        if !NSWorkspace.shared.open(tempURL) {
            throw PSTViewerError.attachmentError(
                "No application available to open "
                + "\"\(filename)\"."
            )
        }
    }

    /// Removes all temp files created by openAttachment.
    func cleanupTempFiles() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
    }

    deinit {
        let urls = tempFiles
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
