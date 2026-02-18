//
//  FreePSTViewerTests.swift
//  FreePSTViewerTests
//
//  Created by Rex Lorenzo on 8/3/25.
//

import Foundation
import Testing
@testable import FreePSTViewer
@preconcurrency import PstReader

// MARK: - Fixture Helpers

private final class BundleFinder {}

private func fixtureURL(_ filename: String) -> URL {
    let name = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    let bundle = Bundle(for: BundleFinder.self)
    if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") {
        return url
    }
    // Fallback for flat bundle layouts
    guard let url = bundle.url(forResource: name, withExtension: ext) else {
        fatalError("Fixture not found in test bundle: \(filename)")
    }
    return url
}

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
