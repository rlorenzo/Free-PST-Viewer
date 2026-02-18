import Foundation
@preconcurrency import PstReader

@MainActor
class EmailDetailViewModel: ObservableObject {
    @Published var detailedMessage: PstFile.Message?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let parserService: PSTParserService

    init(parserService: PSTParserService) {
        self.parserService = parserService
    }

    func loadDetails(for message: PstFile.Message) async {
        isLoading = true
        errorMessage = nil
        do {
            detailedMessage = try await parserService.getMessageDetails(for: message)
        } catch {
            errorMessage = PSTViewerError.parseError(error.localizedDescription).errorDescription
            detailedMessage = nil
        }
        isLoading = false
    }

    func clear() {
        detailedMessage = nil
        errorMessage = nil
    }
}
