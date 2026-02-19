import AppKit
import Foundation
@preconcurrency import PstReader

/// Handles attachment save and open operations.
@MainActor
class AttachmentService {
    private let parserService: PSTParserService
    private var tempFiles: [URL] = []

    private static let dangerousExtensions: Set<String> = [
        "exe", "bat", "cmd", "com", "msi", "scr", "pif",
        "app", "scpt", "scptd", "command", "action",
        "sh", "bash", "zsh", "csh",
        "js", "jse", "vbs", "vbe", "wsf", "wsh", "ps1",
        "jar", "py", "rb", "pl"
    ]

    init(parserService: PSTParserService) {
        self.parserService = parserService
        cleanupStaleFiles()
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
    /// launching with the default app. Prompts the user for
    /// confirmation when the file extension is potentially
    /// dangerous.
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
        let filename = URL(fileURLWithPath: rawFilename)
            .lastPathComponent
            .replacingOccurrences(of: "..", with: "_")

        if isDangerous(filename: filename) {
            guard confirmOpen(filename: filename) else { return }
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "FreePSTViewer", isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let nameURL = URL(fileURLWithPath: filename)
        let base = nameURL.deletingPathExtension().lastPathComponent
        let ext = nameURL.pathExtension
        let uniqueName = ext.isEmpty
            ? "\(base)_\(UUID().uuidString)"
            : "\(base)_\(UUID().uuidString).\(ext)"
        let tempURL = tempDir.appendingPathComponent(uniqueName)
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

    private func isDangerous(filename: String) -> Bool {
        let ext = (filename as NSString)
            .pathExtension.lowercased()
        return Self.dangerousExtensions.contains(ext)
    }

    private func confirmOpen(filename: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Open "\(filename)"?"
        alert.informativeText =
            "This file type may be executable. "
            + "Only open it if you trust the source."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Removes stale temp files from previous sessions that
    /// are older than one hour.
    private nonisolated func cleanupStaleFiles() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("FreePSTViewer")
        guard let contents = try? fm.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let cutoff = Date(timeIntervalSinceNow: -3600)
        for url in contents {
            guard let values = try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
            ),
            let modified = values.contentModificationDate,
            modified < cutoff else { continue }
            try? fm.removeItem(at: url)
        }
    }

    deinit {
        let urls = tempFiles
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
