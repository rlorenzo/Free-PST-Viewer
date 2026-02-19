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
        var failCount = 0
        for (index, email) in emails.enumerated() {
            do {
                let detailed = try await parserService
                    .getMessageDetails(for: email)
                var filename =
                    ExportService.suggestedFilename(
                        for: detailed, format: format
                    )
                // Avoid name collisions by appending index
                let ext = format == .eml ? "eml" : "txt"
                let base = String(
                    filename.dropLast(ext.count + 1)
                )
                filename = "\(base)_\(index + 1).\(ext)"
                let url = directory.appendingPathComponent(
                    filename
                )
                try service.exportEmail(
                    detailed, to: url, format: format
                )
            } catch {
                failCount += 1
            }
        }
        if failCount > 0 {
            errorMessage = PSTViewerError.exportError(
                "\(failCount) email(s) failed to export."
            ).errorDescription
        }
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
