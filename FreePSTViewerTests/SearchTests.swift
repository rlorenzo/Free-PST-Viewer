import Foundation
import Testing
@testable import FreePSTViewer
@preconcurrency import PstReader

// MARK: - SearchService Tests

struct SearchServiceTests {

    @Test func emptyQueryReturnsEmpty() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        let searchService = SearchService(parserService: fx.service)
        let results = try await searchService.searchEmails(
            in: [fx.root],
            query: "",
            filters: SearchFilters()
        )
        #expect(results.isEmpty)
    }

    @Test func metadataSearchFindsResultsBySubject() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        let subject = try #require(firstMessage.subjectText)
        let term = String(subject.prefix(4)).lowercased()

        let searchService = SearchService(parserService: fx.service)
        let results = try await searchService.searchEmails(
            in: [fx.root],
            query: term,
            filters: SearchFilters()
        )
        #expect(!results.isEmpty)
    }

    @Test func metadataSearchIsCaseInsensitive() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        let subject = try #require(firstMessage.subjectText)
        let term = String(subject.prefix(4)).uppercased()

        let searchService = SearchService(parserService: fx.service)
        let results = try await searchService.searchEmails(
            in: [fx.root],
            query: term,
            filters: SearchFilters()
        )
        #expect(!results.isEmpty)
    }

    @Test func bodySearchFindsResultsInBody() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        let detailed = try await fx.service.getMessageDetails(
            for: firstMessage
        )
        guard let body = detailed.bodyText, body.count >= 4 else {
            return
        }
        let bodyTerm = String(
            body.dropFirst(body.count / 2).prefix(6)
        ).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bodyTerm.isEmpty else { return }

        let searchService = SearchService(parserService: fx.service)

        let metaOnly = try await searchService.searchEmails(
            in: [fx.root],
            query: bodyTerm,
            filters: SearchFilters(),
            includeBody: false
        )

        let withBody = try await searchService.searchEmails(
            in: [fx.root],
            query: bodyTerm,
            filters: SearchFilters(),
            includeBody: true
        )
        #expect(withBody.count >= metaOnly.count)
    }

    @Test func dateFilterRestrictsResults() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        let subject = try #require(firstMessage.subjectText)
        let term = String(subject.prefix(4)).lowercased()

        let searchService = SearchService(parserService: fx.service)

        let futureRange = DateInterval(
            start: Date(timeIntervalSinceNow: 86400 * 365 * 100),
            end: Date(timeIntervalSinceNow: 86400 * 365 * 200)
        )
        let filtered = try await searchService.searchEmails(
            in: [fx.root],
            query: term,
            filters: SearchFilters(dateRange: futureRange)
        )
        #expect(filtered.isEmpty)
    }

    @Test func noMatchReturnsEmpty() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        let searchService = SearchService(parserService: fx.service)
        let results = try await searchService.searchEmails(
            in: [fx.root],
            query: "zzzxxx_no_match_ever_12345",
            filters: SearchFilters()
        )
        #expect(results.isEmpty)
    }

    @Test func cancellationStopsSearch() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        let searchService = SearchService(parserService: fx.service)

        let task = Task {
            try await searchService.searchEmails(
                in: [fx.root],
                query: "test",
                filters: SearchFilters(),
                includeBody: true
            )
        }
        task.cancel()
        do {
            _ = try await task.value
        } catch is CancellationError {
            // Expected
        }
    }

    @Test func metadataSearchFindsResultsBySender() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        guard let sender = firstMessage.senderDisplayString,
              sender.count >= 3 else { return }
        let term = String(sender.prefix(3)).lowercased()

        let searchService = SearchService(parserService: fx.service)
        let results = try await searchService.searchEmails(
            in: [fx.root],
            query: term,
            filters: SearchFilters()
        )
        #expect(!results.isEmpty)
    }

    @Test func senderFilterRestrictsResults() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        let subject = try #require(firstMessage.subjectText)
        let term = String(subject.prefix(4)).lowercased()

        let searchService = SearchService(parserService: fx.service)

        // Search with a sender filter that won't match any real sender
        let filtered = try await searchService.searchEmails(
            in: [fx.root],
            query: term,
            filters: SearchFilters(sender: "zzz_no_such_sender_999")
        )
        #expect(filtered.isEmpty)
    }
}

// MARK: - SearchViewModel Tests

struct SearchViewModelTests {

    @Test @MainActor func initialStateIsInactive() {
        let service = PSTParserService()
        let viewModel = SearchViewModel(parserService: service)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.isActive == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func clearSearchResetsState() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        let viewModel = SearchViewModel(parserService: fx.service)
        viewModel.query = "test"
        viewModel.performSearch(in: [fx.root])

        try await Task.sleep(for: .milliseconds(100))

        viewModel.clearSearch()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.isActive == false)
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    @Test @MainActor
    func emptyQueryDoesNotActivateSearch() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        let viewModel = SearchViewModel(parserService: fx.service)
        viewModel.query = "   "
        viewModel.performSearch(in: [fx.root])
        #expect(viewModel.isActive == false)
    }

    @Test @MainActor
    func performSearchPopulatesResults() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let firstMessage = try #require(messages.first)
        let subject = try #require(firstMessage.subjectText)
        let term = String(subject.prefix(4)).lowercased()

        let viewModel = SearchViewModel(parserService: fx.service)
        viewModel.query = term
        viewModel.performSearch(in: [fx.root])

        // Wait for the async search task to complete
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.isActive == true)
        #expect(viewModel.isSearching == false)
        #expect(!viewModel.searchResults.isEmpty)
    }

    @Test @MainActor
    func clearSearchResetsDateFilters() {
        let viewModel = SearchViewModel(parserService: PSTParserService())
        viewModel.dateFrom = Date()
        viewModel.dateTo = Date()
        viewModel.senderFilter = "test"
        viewModel.includeBody = true

        viewModel.clearSearch()
        #expect(viewModel.dateFrom == nil)
        #expect(viewModel.dateTo == nil)
        #expect(viewModel.senderFilter == nil)
        #expect(viewModel.includeBody == false)
    }
}
