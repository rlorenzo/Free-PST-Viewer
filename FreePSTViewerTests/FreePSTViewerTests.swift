import Foundation
import Testing
@testable import FreePSTViewer
@preconcurrency import PstReader

// MARK: - PSTParserService Tests

struct PSTParserServiceTests {

    @Test func loadPSTFileReturnsFileWithRootFolder() async throws {
        let service = PSTParserService()
        let file = try await service.loadPSTFile(from: fixtureURL("test_unicode.pst"))
        #expect(file.rootFolder != nil)
    }

    @Test func loadPSTFilePreWarmsRootFolderChildren() async throws {
        let service = PSTParserService()
        let file = try await service.loadPSTFile(
            from: fixtureURL("four_nesting_levels.pst")
        )
        let root = try #require(file.rootFolder)
        #expect(!root.children.isEmpty)
    }

    @Test func loadPSTFileThrowsForInvalidPath() async {
        let service = PSTParserService()
        await #expect(throws: Error.self) {
            try await service.loadPSTFile(
                from: URL(fileURLWithPath: "/nonexistent.pst")
            )
        }
    }

    @Test func getMessagesReturnsMessages() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        let folder = try await firstFolderWithEmails(in: fx.root, service: fx.service)
        if let folder = folder {
            let messages = try await fx.service.getMessages(from: folder)
            #expect(!messages.isEmpty)
        }
    }

    @Test func getMessageDetailsLoadsBody() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else {
            return
        }
        let messages = try await fx.service.getMessages(from: folder)
        let detailed = try await fx.service.getMessageDetails(for: messages[0])
        #expect(detailed.hasDetails)
    }
}

// MARK: - PSTViewModel Tests

struct PSTViewModelTests {

    @Test @MainActor func loadFileSetsCurrentFile() async {
        let viewModel = PSTViewModel()
        await viewModel.loadFile(from: fixtureURL("test_unicode.pst"))
        #expect(viewModel.currentFile != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test @MainActor func loadFileShowsErrorForInvalidPath() async {
        let viewModel = PSTViewModel()
        await viewModel.loadFile(
            from: URL(fileURLWithPath: "/nonexistent.pst")
        )
        #expect(viewModel.currentFile == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test @MainActor func closeFileClearsState() async {
        let viewModel = PSTViewModel()
        await viewModel.loadFile(from: fixtureURL("test_unicode.pst"))
        #expect(viewModel.currentFile != nil)
        viewModel.closeFile()
        #expect(viewModel.currentFile == nil)
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - FolderViewModel Tests

struct FolderViewModelTests {

    @Test @MainActor func toggleExpansionAddsAndRemovesID() {
        let viewModel = FolderViewModel()
        let id = "0.1.Inbox"

        viewModel.toggleExpansion(id: id)
        #expect(viewModel.expandedFolderIDs.contains(id))

        viewModel.toggleExpansion(id: id)
        #expect(!viewModel.expandedFolderIDs.contains(id))
    }

    @Test @MainActor
    func expandTopLevelExpandsAllChildren() async throws {
        let service = PSTParserService()
        let file = try await service.loadPSTFile(
            from: fixtureURL("four_nesting_levels.pst")
        )
        let root = try #require(file.rootFolder)

        let viewModel = FolderViewModel()
        viewModel.expandTopLevel(rootFolder: root)
        #expect(viewModel.expandedFolderIDs.count == root.children.count)
    }

    @Test @MainActor
    func expandTopLevelClearsPreviousExpansions() async throws {
        let service = PSTParserService()
        let file = try await service.loadPSTFile(
            from: fixtureURL("four_nesting_levels.pst")
        )
        let root = try #require(file.rootFolder)

        let viewModel = FolderViewModel()
        viewModel.expandedFolderIDs.insert("stale-id")
        viewModel.expandTopLevel(rootFolder: root)
        #expect(!viewModel.expandedFolderIDs.contains("stale-id"))
    }

    @Test @MainActor func selectFolderUpdatesState() async throws {
        let service = PSTParserService()
        let file = try await service.loadPSTFile(
            from: fixtureURL("test_unicode.pst")
        )
        let root = try #require(file.rootFolder)
        let child = try #require(root.children.first)

        let viewModel = FolderViewModel()
        let id = viewModel.folderID(child, path: [0, 0])
        viewModel.selectFolder(child, id: id)

        #expect(viewModel.selectedFolder != nil)
        #expect(viewModel.selectedFolderID == id)
    }
}

// MARK: - EmailListViewModel Tests

struct EmailListViewModelTests {

    @Test @MainActor func loadEmailsPopulatesList() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: folder)

        #expect(!viewModel.emails.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func loadEmailsClearsSelection() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        viewModel.selectedEmailIndex = 0
        await viewModel.loadEmails(for: folder)

        #expect(viewModel.selectedEmailIndex == nil)
    }

    @Test @MainActor func selectedMessageReturnsCorrectEmail() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: folder)

        #expect(viewModel.selectedMessage == nil)

        viewModel.selectedEmailIndex = 0
        #expect(viewModel.selectedMessage != nil)
    }

    @Test @MainActor func selectedMessageReturnsNilForOutOfBoundsIndex() {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)

        viewModel.selectedEmailIndex = 5
        #expect(viewModel.selectedMessage == nil)
    }

    @Test @MainActor func sortByDateDescendingIsDefault() {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)
        #expect(viewModel.sortOrder == .dateDescending)
    }

    @Test @MainActor func sortChangesOrder() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }

        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: folder)

        viewModel.sort(by: .subjectAscending)
        #expect(viewModel.sortOrder == .subjectAscending)

        if viewModel.emails.count >= 2 {
            let first = viewModel.emails[0].subjectText ?? ""
            let second = viewModel.emails[1].subjectText ?? ""
            #expect(first <= second)
        }
    }

    @Test @MainActor func sortColumnLabelReflectsOrder() {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)

        #expect(viewModel.sortColumnLabel == "Date")

        viewModel.sort(by: .senderAscending)
        #expect(viewModel.sortColumnLabel == "From")

        viewModel.sort(by: .sizeDescending)
        #expect(viewModel.sortColumnLabel == "Size")

        viewModel.sort(by: .subjectAscending)
        #expect(viewModel.sortColumnLabel == "Subject")
    }

    @Test @MainActor func isSortAscendingReflectsDirection() {
        let service = PSTParserService()
        let viewModel = EmailListViewModel(parserService: service)

        #expect(viewModel.isSortAscending == false)

        viewModel.sort(by: .dateAscending)
        #expect(viewModel.isSortAscending == true)

        viewModel.sort(by: .senderDescending)
        #expect(viewModel.isSortAscending == false)
    }

    @Test @MainActor func loadEmptyFolderResultsInEmptyList() async throws {
        let fx = try await loadFixtureRoot("four_nesting_levels.pst")
        let viewModel = EmailListViewModel(parserService: fx.service)
        await viewModel.loadEmails(for: fx.root)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - EmailDetailViewModel Tests

struct EmailDetailViewModelTests {

    @Test @MainActor func loadDetailsPopulatesMessage() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let viewModel = EmailDetailViewModel(parserService: fx.service)
        await viewModel.loadDetails(for: message)

        #expect(viewModel.detailedMessage != nil)
        #expect(viewModel.detailedMessage?.hasDetails == true)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func loadDetailsHasBodyContent() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let viewModel = EmailDetailViewModel(parserService: fx.service)
        await viewModel.loadDetails(for: message)

        let detailed = try #require(viewModel.detailedMessage)
        let hasBody = detailed.bodyText != nil || detailed.bodyHtmlString != nil
        #expect(hasBody)
    }

    @Test @MainActor func clearResetsState() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let viewModel = EmailDetailViewModel(parserService: fx.service)
        await viewModel.loadDetails(for: message)
        #expect(viewModel.detailedMessage != nil)

        viewModel.clear()
        #expect(viewModel.detailedMessage == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func initialStateIsEmpty() {
        let service = PSTParserService()
        let viewModel = EmailDetailViewModel(parserService: service)

        #expect(viewModel.detailedMessage == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
}
