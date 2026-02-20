import AppKit
import Foundation
@preconcurrency import PstReader

@MainActor
class EmailListViewModel: ObservableObject {
    @Published var emails: [PstFile.Message] = []
    @Published var selectedEmailIndex: Int?
    @Published var sortOrder: EmailSortOrder = .dateDescending
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var exportProgress: Double?

    var selectedMessage: PstFile.Message? {
        guard let index = selectedEmailIndex, emails.indices.contains(index) else { return nil }
        return emails[index]
    }

    private let parserService: PSTParserService

    init(parserService: PSTParserService) {
        self.parserService = parserService
    }

    func loadEmails(for folder: PstFile.Folder) async {
        isLoading = true
        errorMessage = nil
        selectedEmailIndex = nil
        do {
            emails = try await parserService.getMessages(from: folder)
            sortEmails()
        } catch {
            errorMessage = PSTViewerError.parseError(error.localizedDescription).errorDescription
            emails = []
        }
        isLoading = false
    }

    func sort(by order: EmailSortOrder) {
        sortOrder = order
        sortEmails()
    }

    var sortColumnLabel: String {
        switch sortOrder {
        case .dateDescending, .dateAscending: return "Date"
        case .subjectDescending, .subjectAscending: return "Subject"
        case .senderDescending, .senderAscending: return "From"
        case .sizeDescending, .sizeAscending: return "Size"
        }
    }

    var isSortAscending: Bool {
        switch sortOrder {
        case .dateAscending, .subjectAscending, .senderAscending, .sizeAscending:
            return true
        case .dateDescending, .subjectDescending, .senderDescending, .sizeDescending:
            return false
        }
    }

    func exportSingleEmail(
        _ message: PstFile.Message,
        format: ExportFormat
    ) async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue =
            ExportService.suggestedFilename(
                for: message, format: format
            )
        guard panel.runModal() == .OK,
              let url = panel.url else { return }
        do {
            let detailed = try await parserService
                .getMessageDetails(for: message)
            let service = ExportService()
            try service.exportEmail(
                detailed, to: url, format: format
            )
        } catch {
            errorMessage = PSTViewerError.exportError(
                error.localizedDescription
            ).errorDescription
        }
    }

    func batchExport(
        to directory: URL,
        format: ExportFormat
    ) async {
        let service = ExportService()
        let total = emails.count
        exportProgress = 0
        var failures: [String] = []
        for (index, email) in emails.enumerated() {
            do {
                try Task.checkCancellation()
                let detailed = try await parserService
                    .getMessageDetails(for: email)
                let exportURL = uniqueExportURL(
                    in: directory, for: detailed,
                    index: index, format: format
                )
                try service.exportEmail(
                    detailed, to: exportURL, format: format
                )
            } catch is CancellationError {
                break
            } catch {
                let subject = email.subjectText
                    ?? "Email \(index + 1)"
                failures.append(
                    "\(subject): \(error.localizedDescription)"
                )
            }
            exportProgress = Double(index + 1) / Double(total)
        }
        exportProgress = nil
        if !failures.isEmpty {
            let summary = failures.count == 1
                ? failures[0]
                : "\(failures.count) email(s) failed:\n"
                    + failures.prefix(5).joined(separator: "\n")
                    + (failures.count > 5
                        ? "\n...and \(failures.count - 5) more"
                        : "")
            errorMessage = PSTViewerError.exportError(
                summary
            ).errorDescription
        }
    }

    private func uniqueExportURL(
        in directory: URL,
        for message: PstFile.Message,
        index: Int,
        format: ExportFormat
    ) -> URL {
        let ext = format == .eml ? "eml" : "txt"
        let base = String(
            ExportService.suggestedFilename(
                for: message, format: format
            ).dropLast(ext.count + 1)
        )
        let filename = "\(base)_\(index + 1).\(ext)"
        var exportURL = directory.appendingPathComponent(filename)
        var suffix = 1
        let fileManager = FileManager.default
        while fileManager.fileExists(atPath: exportURL.path) {
            let unique = "\(base)_\(index + 1)_\(suffix).\(ext)"
            exportURL = directory.appendingPathComponent(unique)
            suffix += 1
        }
        return exportURL
    }

    private func sortEmails() {
        switch sortOrder {
        case .dateDescending:
            emails.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        case .dateAscending:
            emails.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        case .subjectDescending:
            emails.sort { ($0.subjectText ?? "") > ($1.subjectText ?? "") }
        case .subjectAscending:
            emails.sort { ($0.subjectText ?? "") < ($1.subjectText ?? "") }
        case .senderDescending:
            emails.sort { ($0.senderDisplayString ?? "") > ($1.senderDisplayString ?? "") }
        case .senderAscending:
            emails.sort { ($0.senderDisplayString ?? "") < ($1.senderDisplayString ?? "") }
        case .sizeDescending:
            emails.sort { ($0.sizeInBytes ?? 0) > ($1.sizeInBytes ?? 0) }
        case .sizeAscending:
            emails.sort { ($0.sizeInBytes ?? 0) < ($1.sizeInBytes ?? 0) }
        }
    }
}
