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

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Verify the file exists and try opening it again."
        case .invalidFileFormat:
            return "Ensure the file is a valid .pst or .ost file."
        case .parseError:
            return "The file may be corrupted. Try a different file."
        case .exportError:
            return "Check that you have write permissions to the destination."
        case .attachmentError:
            return "Try saving the attachment to a different location."
        }
    }
}
