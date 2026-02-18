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
