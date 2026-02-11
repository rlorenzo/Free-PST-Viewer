import Foundation
@preconcurrency import PstReader

@MainActor
class EmailListViewModel: ObservableObject {
    @Published var emails: [PstFile.Message] = []
    @Published var selectedEmailIndex: Int?
    @Published var sortOrder: EmailSortOrder = .dateDescending
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let parserService: PSTParserService

    init(parserService: PSTParserService) {
        self.parserService = parserService
    }

    func loadEmails(for folder: PstFile.Folder) async {
        isLoading = true
        errorMessage = nil
        do {
            emails = try await parserService.getMessages(from: folder)
            sortEmails()
        } catch {
            errorMessage = PSTViewerError.parseError(error.localizedDescription).errorDescription
            emails = []
        }
        isLoading = false
    }

    func selectEmail(at index: Int) {
        selectedEmailIndex = index
    }

    func sort(by order: EmailSortOrder) {
        sortOrder = order
        sortEmails()
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
