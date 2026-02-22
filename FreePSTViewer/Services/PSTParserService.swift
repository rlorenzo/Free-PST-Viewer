import Foundation
@preconcurrency import PstReader

/// Service that wraps PstReader operations on a background queue.
/// PstReader types are not Sendable, so all access goes through a serial DispatchQueue
/// bridged to async/await via withCheckedThrowingContinuation.
class PSTParserService {
    private let queue = DispatchQueue(label: "com.freepstviewer.parser", qos: .userInitiated)
    private var cache: [Data: PstFile.Message] = [:]
    private var cacheOrder: [Data] = []
    private let maxCacheSize = 50

    func loadPSTFile(from url: URL) async throws -> PstFile {
        try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                self.cache.removeAll()
                self.cacheOrder.removeAll()
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

    func clearCache() {
        queue.async {
            self.cache.removeAll()
            self.cacheOrder.removeAll()
        }
    }

    func getMessages(
        from folder: PstFile.Folder
    ) async throws -> [PstFile.Message] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    try folder.getMessages()
                })
            }
        }
    }

    func getMessageDetails(
        for message: PstFile.Message
    ) async throws -> PstFile.Message {
        try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                if let key = message.searchKey,
                   let cached = self.cache[key] {
                    self.promoteCacheEntry(key)
                    continuation.resume(returning: cached)
                    return
                }
                continuation.resume(with: Result {
                    let detailed = try message.getMessageDetails()
                    if let key = message.searchKey {
                        self.insertCacheEntry(key, value: detailed)
                    }
                    return detailed
                })
            }
        }
    }

    func getAttachmentDetails(
        for attachment: PstFile.Attachment
    ) async throws -> PstFile.Attachment {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    try attachment.getAttachmentDetails()
                })
            }
        }
    }

    // MARK: - Cache helpers (must be called on self.queue)

    private func promoteCacheEntry(_ key: Data) {
        if let idx = cacheOrder.firstIndex(of: key) {
            cacheOrder.remove(at: idx)
            cacheOrder.append(key)
        }
    }

    private func insertCacheEntry(
        _ key: Data,
        value: PstFile.Message
    ) {
        if let idx = cacheOrder.firstIndex(of: key) {
            cacheOrder.remove(at: idx)
        }
        cache[key] = value
        cacheOrder.append(key)
        if cacheOrder.count > maxCacheSize {
            let evicted = cacheOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}
