import Foundation
@preconcurrency import PstReader

struct SearchService {
    static let maxResults = 10_000
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
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        var results: [PstFile.Message] = []
        try await searchRecursively(
            folders: folders,
            query: lowercasedQuery,
            filters: filters,
            includeBody: includeBody,
            results: &results
        )
        return results
    }

    private func searchRecursively(
        folders: [PstFile.Folder],
        query: String,
        filters: SearchFilters,
        includeBody: Bool,
        results: inout [PstFile.Message]
    ) async throws {
        for folder in folders {
            try Task.checkCancellation()
            guard results.count < Self.maxResults else { return }
            let messages = try await parserService.getMessages(from: folder)
            for message in messages {
                try Task.checkCancellation()
                guard results.count < Self.maxResults else { return }
                if !passesFilters(message, filters: filters) {
                    continue
                }
                // Stage 1: metadata search — if matched, skip body
                // search via `continue` to avoid duplicates.
                if matchesMetadata(message, query: query) {
                    results.append(message)
                    continue
                }
                // Stage 2: body search (opt-in)
                if includeBody {
                    let detailed = try await parserService.getMessageDetails(
                        for: message
                    )
                    if let body = detailed.bodyText?.lowercased(),
                       body.contains(query) {
                        results.append(message)
                    }
                }
            }
            // Recurse into subfolders
            try await searchRecursively(
                folders: folder.children,
                query: query,
                filters: filters,
                includeBody: includeBody,
                results: &results
            )
        }
    }

    private func matchesMetadata(
        _ message: PstFile.Message,
        query: String
    ) -> Bool {
        if let subject = message.subjectText?.lowercased(),
           subject.contains(query) {
            return true
        }
        if let sender = message.senderDisplayString?.lowercased(),
           sender.contains(query) {
            return true
        }
        return false
    }

    private func passesFilters(
        _ message: PstFile.Message,
        filters: SearchFilters
    ) -> Bool {
        if let dateRange = filters.dateRange {
            guard let date = message.date,
                  dateRange.contains(date) else {
                return false
            }
        }
        if let senderFilter = filters.sender, !senderFilter.isEmpty {
            let lowered = senderFilter.lowercased()
            let matchesSender = message.senderDisplayString?
                .lowercased().contains(lowered) ?? false
            let matchesAddress = message.senderAddress?
                .lowercased().contains(lowered) ?? false
            if !matchesSender && !matchesAddress {
                return false
            }
        }
        if let hasAttachments = filters.hasAttachments {
            if message.hasFileAttachments != hasAttachments {
                return false
            }
        }
        return true
    }
}
