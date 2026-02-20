import Foundation

enum PSTViewerError: LocalizedError {
    case fileNotFound
    case invalidFileFormat(underlying: Error)
    case parseError(String)
    case exportError(String)
    case attachmentError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The selected file could not be found."
        case .invalidFileFormat(let error):
            return "Invalid Outlook data file: \(error.localizedDescription)"
        case .parseError(let message):
            return "Error reading file: \(message)"
        case .exportError(let message):
            return "Export failed: \(message)"
        case .attachmentError(let message):
            return "Attachment error: \(message)"
        }
    }
}
