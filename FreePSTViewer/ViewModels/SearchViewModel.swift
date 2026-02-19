import Foundation
@preconcurrency import PstReader

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var isSearching = false
    @Published var searchResults: [PstFile.Message] = []
    @Published var includeBody = false
    @Published var dateFrom: Date?
    @Published var dateTo: Date?
    @Published var senderFilter: String?
    @Published var errorMessage: String?
    @Published var isActive = false

    private let searchService: SearchService
    private var searchTask: Task<Void, Never>?

    init(parserService: PSTParserService) {
        self.searchService = SearchService(parserService: parserService)
    }

    func performSearch(in folders: [PstFile.Folder]) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        searchTask?.cancel()
        isSearching = true
        isActive = true
        errorMessage = nil
        searchResults = []

        let currentQuery = query
        let currentIncludeBody = includeBody
        let filters = buildFilters()

        searchTask = Task {
            do {
                let results = try await searchService.searchEmails(
                    in: folders,
                    query: currentQuery,
                    filters: filters,
                    includeBody: currentIncludeBody
                )
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch is CancellationError {
                // Search was cancelled, no action needed
            } catch {
                if !Task.isCancelled {
                    errorMessage = PSTViewerError.parseError(
                        error.localizedDescription
                    ).errorDescription
                }
            }
            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        isSearching = false
        searchResults = []
        isActive = false
        errorMessage = nil
        dateFrom = nil
        dateTo = nil
        senderFilter = nil
        includeBody = false
    }

    private func buildFilters() -> SearchFilters {
        var dateRange: DateInterval?
        if let from = dateFrom, let to = dateTo {
            dateRange = DateInterval(start: from, end: to)
        } else if let from = dateFrom {
            dateRange = DateInterval(start: from, end: .distantFuture)
        } else if let to = dateTo {
            dateRange = DateInterval(start: .distantPast, end: to)
        }
        let sender = senderFilter?.trimmingCharacters(
            in: .whitespaces
        )
        return SearchFilters(
            dateRange: dateRange,
            sender: sender?.isEmpty == true ? nil : sender
        )
    }
}
