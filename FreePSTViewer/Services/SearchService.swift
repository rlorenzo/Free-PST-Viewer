import Foundation
@preconcurrency import PstReader

struct SearchService {
    private let parserService: PSTParserService

    init(parserService: PSTParserService) {
        self.parserService = parserService
    }

    func searchEmails(
        in folders: [PstFile.Folder],
        query: String,
        filters: SearchFilters,
        includeBody: Bool = false
    ) async throws -> [PstFile.Message] {
        // TODO: Implement in Milestone C
        return []
    }
}
