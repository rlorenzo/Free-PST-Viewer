import Foundation
@preconcurrency import PstReader

/// Service that wraps PstReader operations on a background queue.
/// PstReader types are not Sendable, so all access goes through a serial DispatchQueue
/// bridged to async/await via withCheckedThrowingContinuation.
class PSTParserService {
    private let queue = DispatchQueue(label: "com.freepstviewer.parser", qos: .userInitiated)

    func loadPSTFile(from url: URL) async throws -> PstFile {
        try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                continuation.resume(with: Result {
                    let file = try PstFile(contentsOf: url)
                    // Force rootFolder resolution on this background queue while
                    // file access is guaranteed and memory-mapped pages are warm.
                    _ = file.rootFolder
                    return file
                })
            }
        }
    }

    func getMessages(from folder: PstFile.Folder) async throws -> [PstFile.Message] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try folder.getMessages() })
            }
        }
    }

    func getMessageDetails(for message: PstFile.Message) async throws -> PstFile.Message {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try message.getMessageDetails() })
            }
        }
    }

    func getAttachmentDetails(for attachment: PstFile.Attachment) async throws -> PstFile.Attachment {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try attachment.getAttachmentDetails() })
            }
        }
    }
}
