import Foundation
import Testing
@testable import FreePSTViewer
@preconcurrency import PstReader

// MARK: - ExportService Tests

struct ExportServiceTests {

    private func loadDetailedMessage() async throws -> PstFile.Message {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else {
            throw PSTViewerError.parseError("No folder with emails")
        }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)
        return try await fx.service.getMessageDetails(for: message)
    }

    private func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    @Test func emlExportContainsRequiredHeaders() async throws {
        let message = try await loadDetailedMessage()
        let url = tempURL("eml")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .eml)

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("MIME-Version:") || content.contains("Mime-Version:"))

        if message.subjectText != nil {
            #expect(content.contains("Subject:"))
        }
    }

    @Test func emlExportContainsBody() async throws {
        let message = try await loadDetailedMessage()
        let url = tempURL("eml")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .eml)

        let content = try String(contentsOf: url, encoding: .utf8)
        let hasBody = message.bodyText != nil || message.bodyHtmlString != nil
        if hasBody {
            #expect(content.count > 100)
        }
    }

    @Test func txtExportIsReadable() async throws {
        let message = try await loadDetailedMessage()
        let url = tempURL("txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .txt)

        let content = try String(contentsOf: url, encoding: .utf8)
        if let subject = message.subjectText {
            #expect(content.contains("Subject: \(subject)"))
        }
        #expect(!content.contains("</html>"))
    }

    @Test func txtExportContainsHeaders() async throws {
        let message = try await loadDetailedMessage()
        let url = tempURL("txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .txt)

        let content = try String(contentsOf: url, encoding: .utf8)
        if message.senderDisplayName != nil
            || message.senderAddress != nil {
            #expect(content.contains("From:"))
        }
    }

    @Test func emlDateFormatIsRFC2822() throws {
        let service = ExportService()
        let date = Date(timeIntervalSince1970: 1_000_000_000)
        let formatted = service.rfc2822Date(date)
        #expect(formatted.contains("2001"))
        #expect(formatted.contains("Sep"))
        let dayPattern = try #require(
            try? NSRegularExpression(
                pattern: "^[A-Z][a-z]{2}, \\d{2} [A-Z][a-z]{2} \\d{4}"
            )
        )
        let range = NSRange(formatted.startIndex..., in: formatted)
        #expect(dayPattern.firstMatch(in: formatted, range: range) != nil)
    }

    @Test func timestampPreservation() async throws {
        let message = try await loadDetailedMessage()
        let url = tempURL("eml")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .eml)

        if let originalDate = message.date {
            let attrs = try FileManager.default.attributesOfItem(
                atPath: url.path
            )
            if let modDate = attrs[.modificationDate] as? Date {
                let diff = abs(
                    modDate.timeIntervalSince(originalDate)
                )
                #expect(diff < 2)
            }
            if let createDate = attrs[.creationDate] as? Date {
                let diff = abs(
                    createDate.timeIntervalSince(originalDate)
                )
                #expect(diff < 2)
            }
        }
    }

    @Test func saveAttachmentWritesData() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        for msg in messages {
            let detailed = try await fx.service.getMessageDetails(for: msg)
            if detailed.attachments.isEmpty { continue }
            let attachment = try await fx.service.getAttachmentDetails(
                for: detailed.attachments[0]
            )
            guard attachment.fileData != nil else { continue }

            let url = tempURL(
                (attachment.filename as NSString?)?.pathExtension ?? "bin"
            )
            defer { try? FileManager.default.removeItem(at: url) }

            let service = ExportService()
            try service.saveAttachment(attachment, to: url)

            let savedData = try Data(contentsOf: url)
            #expect(savedData == attachment.fileData)
            return
        }
    }

    @Test func emlExportProducesMultipartForDualBody() async throws {
        let message = try await loadDetailedMessage()
        guard message.bodyText != nil,
              message.bodyHtmlString != nil else { return }

        let url = tempURL("eml")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .eml)

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("multipart/alternative"))
        #expect(content.contains("Content-Type: text/plain"))
        #expect(content.contains("Content-Type: text/html"))
        #expect(content.contains("----=_Part_"))
    }

    @Test func emlExportEncodesNonAsciiAsQuotedPrintable() async throws {
        let message = try await loadDetailedMessage()
        let hasBody = message.bodyText != nil
            || message.bodyHtmlString != nil
        guard hasBody else { return }

        let url = tempURL("eml")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .eml)

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(
            content.contains("Content-Transfer-Encoding: quoted-printable")
        )
    }

    @Test func suggestedFilenameSanitizesSpecialCharacters() async throws {
        let message = try await loadDetailedMessage()
        let filename = ExportService.suggestedFilename(
            for: message, format: .eml
        )
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let nameWithoutExt = String(filename.dropLast(4))
        #expect(
            nameWithoutExt.rangeOfCharacter(from: illegal) == nil,
            "Filename should not contain special characters"
        )
        #expect(
            nameWithoutExt.count <= 100,
            "Filename base should be at most 100 characters"
        )
    }

    @Test func suggestedFilenameHasCorrectExtension() async throws {
        let message = try await loadDetailedMessage()
        let emlName = ExportService.suggestedFilename(
            for: message, format: .eml
        )
        let txtName = ExportService.suggestedFilename(
            for: message, format: .txt
        )
        #expect(emlName.hasSuffix(".eml"))
        #expect(txtName.hasSuffix(".txt"))
    }

    @Test func saveAttachmentThrowsForNilFileData() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let detailed = try await fx.service.getMessageDetails(
            for: messages[0]
        )
        guard !detailed.attachments.isEmpty else { return }
        // Raw attachment from getMessageDetails has no fileData yet
        let att = detailed.attachments[0]
        guard att.fileData == nil else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let service = ExportService()
        #expect(throws: PSTViewerError.self) {
            try service.saveAttachment(att, to: url)
        }
    }

    @Test func exportWithNilBodyProducesOutput() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let url = tempURL("eml")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .eml)

        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
    }

    @Test func txtExportWithNilBodyProducesOutput() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let message = try #require(messages.first)

        let url = tempURL("txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExportService()
        try service.exportEmail(message, to: url, format: .txt)

        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
    }
}

// MARK: - AttachmentService Tests

struct AttachmentServiceTests {

    @Test func saveAttachmentWritesFileData() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        for msg in messages {
            let detailed = try await fx.service.getMessageDetails(
                for: msg
            )
            if detailed.attachments.isEmpty { continue }
            let attachment = detailed.attachments[0]
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: url) }

            let service = AttachmentService(
                parserService: fx.service
            )
            try await service.saveAttachment(attachment, to: url)
            let savedData = try Data(contentsOf: url)
            #expect(!savedData.isEmpty)
            return
        }
    }

    @Test func saveAttachmentLoadsDetailsBeforeWriting() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        let detailed = try await fx.service.getMessageDetails(
            for: messages[0]
        )
        guard !detailed.attachments.isEmpty else { return }
        // Use attachment before calling getAttachmentDetails;
        // AttachmentService.saveAttachment should load details internally
        let att = detailed.attachments[0]
        let service = AttachmentService(
            parserService: fx.service
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        try await service.saveAttachment(att, to: url)
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
    }

    @Test func getAttachmentDetailsLoadsData() async throws {
        let fx = try await loadFixtureRoot("test_unicode.pst")
        guard let folder = try await firstFolderWithEmails(
            in: fx.root, service: fx.service
        ) else { return }
        let messages = try await fx.service.getMessages(from: folder)
        for msg in messages {
            let detailed = try await fx.service.getMessageDetails(
                for: msg
            )
            if detailed.attachments.isEmpty { continue }
            let attachment = try await fx.service
                .getAttachmentDetails(for: detailed.attachments[0])
            #expect(attachment.hasDetails)
            return
        }
    }

    @Test func cleanupTempFilesIgnoresUntrackedFiles() async throws {
        let service = AttachmentService(
            parserService: PSTParserService()
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreePSTViewer", isDirectory: true)
            .appendingPathComponent("test_cleanup.txt")
        try FileManager.default.createDirectory(
            at: tempURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("test".utf8).write(to: tempURL)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        // Files not tracked by AttachmentService should not be removed
        service.cleanupTempFiles()
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        try? FileManager.default.removeItem(at: tempURL)
    }
}
