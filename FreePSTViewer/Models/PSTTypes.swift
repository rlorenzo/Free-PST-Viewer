import Foundation

enum EmailSortOrder: Equatable {
    case dateAscending, dateDescending
    case subjectAscending, subjectDescending
    case senderAscending, senderDescending
    case sizeAscending, sizeDescending
}

enum ExportFormat {
    case eml, txt
}

func formatByteCount(_ bytes: UInt32) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

struct SearchFilters {
    let dateRange: DateInterval?
    let sender: String?
    let hasAttachments: Bool?

    init(dateRange: DateInterval? = nil, sender: String? = nil, hasAttachments: Bool? = nil) {
        self.dateRange = dateRange
        self.sender = sender
        self.hasAttachments = hasAttachments
    }
}
