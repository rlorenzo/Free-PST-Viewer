import Foundation
@preconcurrency import PstReader

struct ExportService {
    func exportEmail(_ message: PstFile.Message, to url: URL, format: ExportFormat) throws {
        // TODO: Implement in Milestone C
    }

    func saveAttachment(_ attachment: PstFile.Attachment, to url: URL) throws {
        // TODO: Implement in Milestone C
    }
}
