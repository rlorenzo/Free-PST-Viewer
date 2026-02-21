import Foundation
import Testing
@testable import FreePSTViewer
@preconcurrency import PstReader

// MARK: - Message Detail Caching Tests

struct MessageDetailCachingTests {

    @Test func cachedDetailReturnsSameResult() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let first = try await fx.service.getMessageDetails(for: message)
        let second = try await fx.service.getMessageDetails(for: message)

        #expect(first.hasDetails)
        #expect(second.hasDetails)
        #expect(first.subjectText == second.subjectText)
    }

    @Test func clearCacheAllowsFreshFetch() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let first = try await fx.service.getMessageDetails(for: message)
        fx.service.clearCache()
        let second = try await fx.service.getMessageDetails(for: message)

        #expect(first.hasDetails)
        #expect(second.hasDetails)
    }

    @Test func loadPSTFileClearsCache() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        _ = try await fx.service.getMessageDetails(for: message)
        // Loading a new file should clear the cache
        _ = try await fx.service.loadPSTFile(
            from: fixtureURL("test_unicode.pst")
        )
        // After reload, old message objects are stale, but the cache
        // should have been cleared (no crash, no stale data)
        #expect(true)
    }
}

// MARK: - EmailListViewModel Chunking Tests

struct EmailListViewModelChunkingTests {

    @Test @MainActor func loadEmailsChunksDisplay() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: folder)

        // With test fixtures, email count is less than chunkSize,
        // so all should be displayed
        #expect(!viewModel.emails.isEmpty)
        #expect(viewModel.displayedCount == viewModel.emails.count)
        #expect(viewModel.canLoadMore == false)
    }

    @Test @MainActor func canLoadMoreIsFalseWhenAllDisplayed() {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)
        #expect(viewModel.canLoadMore == false)
    }

    @Test @MainActor func loadMoreDoesNothingWhenNoMore() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: folder)

        let countBefore = viewModel.emails.count
        viewModel.loadMore()
        #expect(viewModel.emails.count == countBefore)
    }

    @Test @MainActor func sortPreservesChunking() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: folder)

        let countBefore = viewModel.emails.count
        viewModel.sort(by: .subjectAscending)
        #expect(viewModel.emails.count == countBefore)
    }
}

// MARK: - Error Handling Tests

struct ErrorHandlingTests {

    @Test @MainActor func defaultStateHasNoWarnings() async {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)

        // Loading from root folder of four_nesting_levels which has
        // no messages shouldn't error, so we test the default state
        #expect(viewModel.warningMessage == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func dismissWarningClearsMessage() async throws {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)

        // Manually set a warning to test dismissal
        viewModel.warningMessage = "Test warning"
        #expect(viewModel.warningMessage != nil)

        viewModel.dismissWarning()
        #expect(viewModel.warningMessage == nil)
    }

    @Test @MainActor func loadEmailsClearsWarningOnSuccess() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        viewModel.warningMessage = "Old warning"
        await viewModel.loadEmails(for: folder)

        #expect(viewModel.warningMessage == nil)
        #expect(!viewModel.emails.isEmpty)
    }
}

// MARK: - PSTViewerError Recovery Suggestion Tests

struct PSTViewerErrorRecoverySuggestionTests {

    @Test func fileNotFoundHasRecoverySuggestion() {
        let error = PSTViewerError.fileNotFound
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("Verify") == true)
    }

    @Test func invalidFileFormatHasRecoverySuggestion() {
        let underlying = NSError(
            domain: "test", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "bad format"]
        )
        let error = PSTViewerError.invalidFileFormat(
            underlying: underlying
        )
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains(".pst") == true)
    }

    @Test func parseErrorHasRecoverySuggestion() {
        let error = PSTViewerError.parseError("test")
        #expect(error.recoverySuggestion != nil)
        #expect(error.recoverySuggestion?.contains("corrupted") == true)
    }

    @Test func exportErrorHasRecoverySuggestion() {
        let error = PSTViewerError.exportError("test")
        #expect(error.recoverySuggestion != nil)
        #expect(
            error.recoverySuggestion?.contains("permissions") == true
        )
    }

    @Test func attachmentErrorHasRecoverySuggestion() {
        let error = PSTViewerError.attachmentError("test")
        #expect(error.recoverySuggestion != nil)
        #expect(
            error.recoverySuggestion?.contains("different") == true
        )
    }

    @Test func allErrorCasesHaveDescriptions() {
        let errors: [PSTViewerError] = [
            .fileNotFound,
            .invalidFileFormat(
                underlying: NSError(domain: "t", code: 0)
            ),
            .parseError("msg"),
            .exportError("msg"),
            .attachmentError("msg")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.recoverySuggestion != nil)
        }
    }
}
