import Foundation
import Testing
@testable import FreePSTViewer
@preconcurrency import PstReader

// MARK: - Fixture Helpers

private final class BundleFinder {}

func fixtureURL(_ filename: String) -> URL {
    let name = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    let bundle = Bundle(for: BundleFinder.self)
    if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") {
        return url
    }
    guard let url = bundle.url(forResource: name, withExtension: ext) else {
        fatalError("Fixture not found in test bundle: \(filename)")
    }
    return url
}

struct FixtureRoot {
    let service: PSTParserService
    let file: PstFile
    let root: PstFile.Folder
}

/// Loads a fixture and returns the root folder.
func loadFixtureRoot(_ filename: String) async throws -> FixtureRoot {
    let service = PSTParserService()
    let file = try await service.loadPSTFile(from: fixtureURL(filename))
    let root = try #require(file.rootFolder)
    return FixtureRoot(service: service, file: file, root: root)
}

/// Finds the first folder that has emails.
func firstFolderWithEmails(
    in folder: PstFile.Folder,
    service: PSTParserService
) async throws -> PstFile.Folder? {
    let messages = try await service.getMessages(from: folder)
    if !messages.isEmpty { return folder }
    for child in folder.children {
        if let found = try await firstFolderWithEmails(in: child, service: service) {
            return found
        }
    }
    return nil
}
