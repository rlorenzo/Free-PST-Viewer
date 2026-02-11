import Foundation

enum EmailSortOrder {
    case dateAscending, dateDescending
    case subjectAscending, subjectDescending
    case senderAscending, senderDescending
    case sizeAscending, sizeDescending
}

enum ExportFormat {
    case eml, txt
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
